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
    var appPolicy: AppPolicy! { get set }

    func handleNewFlow(_ flow: Flow) -> Bool
    func whitelistProxyInFirewall(groupName: String) -> Bool
    func setTunnelNetworkSettings(serverAddress: String, provider: NETransparentProxyProvider, completionHandler: @escaping (Error?) -> Void)
}

final class ProxyEngine: ProxyEngineProtocol {
    public var trafficManager: TrafficManager!
    public var appPolicy: AppPolicy!

    public func handleNewFlow(_ flow: Flow) -> Bool {
        guard isFlowIPv4(flow) else {
            return false
        }

        switch policyFor(flow: flow) {
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

    // Given a flow, return the app policy to apply (.proxy, .block. ignore)
    private func policyFor(flow: Flow) -> AppPolicy.Policy {
        // First try to find a policy for the app using the appId
        let appID = flow.sourceAppSigningIdentifier
        let appIdPolicy = appPolicy.policyFor(appId: appID)

        // If we fail to find a policy from the appId
        // then try using the path (extracted from the audit token)
        // Otherwise, if we find a policy from the appID, return that policy
        guard appIdPolicy == .ignore else {
            return appIdPolicy
        }

        // We failed to find a policy based on appId - let's try the app path
        // In order to find the app path we first have to extract it from the flow's audit token
        let auditToken = flow.sourceAppAuditToken

        guard let path = pathFromAuditToken(token: auditToken) else {
            return .ignore
        }

        // Return the policy for the app (by its path)
        return appPolicy.policyFor(appPath: path)
    }

    // Given an audit token of an app flow - extract out the executable path for
    // the app generating the flow.
    private func pathFromAuditToken(token: Data?) -> String? {
        guard let auditToken = token else {
            log(.warning, "Audit token is nil")
            return nil
        }

        // The pid of the process behind the flow
        var pid: pid_t = 0

        // An audit token is opaque Data - but we can use it to extract the pid (and other things)
        // by converting it to an audit_token_t and then using libbsm APIs to extract what we want.
        auditToken.withUnsafeBytes { bytes in
            let auditTokenValue = bytes.bindMemory(to: audit_token_t.self).baseAddress!.pointee

            // The full C signature is: audit_token_to_au32(audit_token_t atoken, uid_t *auidp, uid_t *euidp, gid_t *egidp, uid_t *ruidp, gid_t *rgidp, pid_t *pidp, au_asid_t *asidp, au_tid_t *tidp)
            // We pass in nil if we're not interested in that value - here we only want the PID, so that's all we request.
            audit_token_to_au32(auditTokenValue, nil, nil, nil, nil, nil, &pid, nil, nil)
        }

        guard pid != 0 else {
            log(.warning, "Could not get a pid from the audit token")
            return nil
        }

        // Get the executable path from the pid
        guard let path = getProcessPath(pid: pid) else {
            log(.warning, "Found a process with pid \(pid) but could not convert to a path")
            return nil
        }

        return path
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
