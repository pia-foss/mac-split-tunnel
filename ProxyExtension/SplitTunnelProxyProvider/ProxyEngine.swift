import Foundation
import NIO
import NetworkExtension

protocol ProxyEngineProtocol {
    var vpnState: VpnState { get }

    func handleNewFlow(_ flow: Flow) -> Bool
    func whitelistProxyInFirewall(groupName: String) -> Bool
    func setTunnelNetworkSettings(serverAddress: String, provider: NETransparentProxyProvider, completionHandler: @escaping (Error?) -> Void)
}

struct SessionConfig {
    var bindIp: String { interface.ip4()! }
    let interface: NetworkInterfaceProtocol
    // We need to make this optional so that we can
    // leave it nil in tests - tests do not use an EventLoopGroup
    let eventLoopGroup: MultiThreadedEventLoopGroup!
}

// Manages core functionality of the Split Tunnel
// * handles flows
// * whitelists in the firewall
// * configures network settings
final class ProxyEngine: ProxyEngineProtocol {
    let vpnState: VpnState

    var sessionConfig: SessionConfig!
    let proxySessionFactory: ProxySessionFactory

    init(vpnState: VpnState, proxySessionFactory: ProxySessionFactory = DefaultProxySessionFactory(),
         config: SessionConfig? = nil) {
        self.vpnState = vpnState

        self.sessionConfig = config ?? Self.defaultSessionConfig(interface: NetworkInterface(interfaceName: vpnState.networkInterface))
        self.proxySessionFactory = proxySessionFactory
    }

    deinit {
        if sessionConfig.eventLoopGroup != nil {
            try! sessionConfig.eventLoopGroup.syncShutdownGracefully()
        }
    }

    public func handleNewFlow(_ flow: Flow) -> Bool {
        NewFlowHandler(vpnState: vpnState, proxySessionFactory: proxySessionFactory, config: sessionConfig).handleNewFlow(flow)
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

    private static func defaultSessionConfig(interface: NetworkInterfaceProtocol) -> SessionConfig {
        // Fundamental config used to establish a session
        SessionConfig(
            interface: interface,
            // Trying with just 1 thread for now, since we dont want to use too many resources on the user's machines.
            // According to SwiftNIO docs it is better to use MultiThreadedEventLoopGroup
            // even in the case of just 1 thread
            eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1)
        )
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
