//
//  ProxyInitializer.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 16/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NetworkExtension

protocol ProxyEngineProtocol {
    var trafficManager: TrafficManager! { get set }
    var vpnState: VpnState! { get set }

    func handleNewFlow(_ flow: Flow) -> Bool
    func whitelistProxyInFirewall(groupName: String) -> Bool
    func setTunnelNetworkSettings(serverAddress: String, provider: NETransparentProxyProvider, completionHandler: @escaping (Error?) -> Void)
}

final class ProxyEngine: ProxyEngineProtocol {
    public var trafficManager: TrafficManager!
    public var vpnState: VpnState!

    public func handleNewFlow(_ flow: Flow) -> Bool {
        guard isFlowIPv4(flow) else {
            return false
        }

        switch FlowPolicy.policyFor(flow: flow, vpnState: vpnState) {
        case .proxy:
            return startProxySession(flow: flow)
        case .block:
            flow.closeReadAndWrite()
            // We return true to indicate to the OS we want to handle the flow, so the app is blocked.
            return true
        case .ignore:
            return false
        }
    }

    // Is the flow IPv4 ? (we only support IPv4 flows at present)
    private func isFlowIPv4(_ flow: Flow) -> Bool {
        let hostName = flow.remoteHostname ?? ""
        // Check if the address is an IPv6 address, and negate it. IPv6 addresses always contain a ":"
        // We can't do the opposite (such as just checking for "." for an IPv4 address) due to IPv4-mapped IPv6 addresses
        // which are IPv6 addresses but include IPv4 address notation.
        return !hostName.contains(":")
    }

    private func startProxySession(flow: Flow) -> Bool {
        let appID = flow.sourceAppSigningIdentifier
        flow.openFlow { error in
            guard error == nil else {
                log(.error, "\(appID) \"\(error!.localizedDescription)\" in \(String(describing: flow.self)) open()")
                return
            }
            self.trafficManager.handleFlowIO(flow)
        }
        return true
    }

    public func whitelistProxyInFirewall(groupName: String) -> Bool {
        // Whitelist this process in the firewall - error logging happens in function
        guard setGidForFirewallWhitelist(groupName: groupName) else {
            log(.error, "failed to set gid")
            return false
        }
        return true
    }

    public func setTunnelNetworkSettings(serverAddress: String, provider: NETransparentProxyProvider, completionHandler: @escaping (Error?) -> Void) {
        // Initiating the rules.
        //
        // Only outbound traffic is supported in NETransparentProxyNetworkSettings
        var includedRules:[NENetworkRule] = []
        var excludedRules: [NENetworkRule] = []

        // We want to be "notified" of all flows (TCP and UDP), so we can decide which to manage.
        // nil subnet and 0 prefix indicate we want to match everything
        let allNetworks = subnetRule(subnet: nil, prefix: 0)

        // Exclude IPv4 LAN networks from the proxy
        // We don't need to exclude localhost as this is excluded by default
        let rfc1918NetworkRules = [
            subnetRule(subnet: "192.168.0.0", prefix: 16),
            subnetRule(subnet: "10.0.0.0", prefix: 8),
            subnetRule(subnet: "172.16.0.0", prefix: 12)
        ]

        includedRules.append(allNetworks)
        excludedRules.append(contentsOf: rfc1918NetworkRules)

        // It is unclear what tunnelRemoteAddress means in the
        // case of NETransparentProxy.
        // header file says: NETransparentProxyNetworkSettings
        // are used to communicate the desired network settings
        // for the proxy.
        // Official docs do not say much about it:
        // https://developer.apple.com/documentation/networkextension/netunnelnetworksettings/1406032-init
        let settings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: serverAddress)
        settings.includedNetworkRules = includedRules
        settings.excludedNetworkRules = excludedRules

        // Because this method executes the block asynchronously, we can't just
        // return true/false (Bool) to indicate applying the settings was successful
        // the only way to indicate it is by executing the completionHandler callback
        // either with nil (success) or error (failure) - that is also why
        // the setTunnelNetworkSettings is a Void method
        provider.setTunnelNetworkSettings(settings) { error in
            if (error != nil) {
                log(.error, "\(error!.localizedDescription) when setting proxy settings")
                completionHandler(error)
            }

            // This is needed in order to make the proxy connect.
            // If omitted the proxy will hang in the "Connecting..." state
            completionHandler(nil)
        }
    }


    // Set the GID of the extension process to the whitelist group (likely "piavpn")
    // This GID is whitelisted by the firewall so we can route packets out
    // the physical interface even when the killswitch is active.
    private func setGidForFirewallWhitelist(groupName: String) -> Bool {
        log(.info, "Trying to set gid of extension (pid: \(getpid()) at \(getProcessPath(pid: getpid())!) to \(groupName)")
        guard let whitelistGid = getGroupIdFromName(groupName: groupName) else {
            log(.error, "Error: unable to get gid for \(groupName) group!")
            return false
        }

        // Setting either the egid or rgid successfully is a success
        guard (setEffectiveGroupID(groupID: whitelistGid) || setRealGroupID(groupID: whitelistGid)) else {
            log(.error, "Error: unable to set group to \(groupName) with gid: \(whitelistGid)!")
            return false
        }

        log(.info, "Should have successfully set gid of extension to \(groupName) with gid: \(whitelistGid)")
        return true
    }

    // Build a rule to match traffic from a subnet and a prefix - default to all protocols (TCP/UDP) and outbound only
    // A nil subnet implies remoteNetwork should be set to nil (which means it'll match all remote networks)
    private func subnetRule(subnet: String?, prefix: Int) -> NENetworkRule {
        return NENetworkRule(
            remoteNetwork: subnet != nil ? NWHostEndpoint(hostname: subnet!, port: "0") : nil,
            remotePrefix: prefix,
            localNetwork: nil,
            localPrefix: 0,
            protocol: .any,
            direction: .outbound
        )
    }

}
