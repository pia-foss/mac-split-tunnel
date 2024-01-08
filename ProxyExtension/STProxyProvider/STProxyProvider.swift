import Foundation
import NetworkExtension
import Puppy

// TODO: Handle DNS requests of managed flows
//  Be aware that returning false in NEDNSProxyProvider handleNewFlow(),
//  the flow is discarded and the connection is closed

// NETransparentProxyProvider is a subclass of NEAppProxyProvider.
// The behaviour is different compared to its super class:
// - Returning NO from handleNewFlow: and handleNewUDPFlow:initialRemoteEndpoint:
//   causes the flow to go to through the default system routing,
//   instead of being closed with a "Connection Refused" error.
// - NEDNSSettings and NEProxySettings specified in NETransparentProxyNetworkSettings are ignored.
//   Flows that match the includedNetworkRules within NETransparentProxyNetworkSettings
//   will use the system default DNS and proxy settings,
//   same as unmanaged (not redirected) flows.
// - Flows that are created using a "connect by name" API
//   (such as Network.framework or NSURLSession)
//   that match the includedNetworkRules will not bypass DNS resolution.
//
// To test that all the flows get captured by the rules, change the
// STProxyProvider class to a NEAppProxyProvider and return false
// in handleNewFlow, then verify that no app can connect to the internet.

class STProxyProvider : NETransparentProxyProvider {

    // MARK: Proxy Properties
    var networkInterface: String?
    var serverAddress: String?
    var appPolicy: AppPolicy
    var trafficManager: TrafficManager!

    // MARK: Proxy Functions
    override init() {
        self.appPolicy = AppPolicy()
        super.init()
    }
    
    override func startProxy(options: [String : Any]?, completionHandler: @escaping (Error?) -> Void) {
        // Ensure the logger is initialized
        guard initializeLogger(options: options) else {
            return
        }
        
        // Checking that all the required settings have been passed to the
        // extension by the ProxyApp
        guard let bypassApps = options!["bypassApps"] as? [String] else {
            Logger.log.error("Error: Cannot find bypassApps in options")
            return
        }
        Logger.log.info("Managing \(bypassApps)")

        guard let vpnOnlyApps = options!["vpnOnlyApps"] as? [String] else {
            Logger.log.error("Error: Cannot find vpnOnlyApps in options")
            return
        }

        guard let networkInterface = options!["networkInterface"] as? String else {
            Logger.log.error("Error: Cannot find networkInterface in options")
            return
        }
        Logger.log.info("Sending flows to interface \(networkInterface)")

        guard let serverAddress = options!["serverAddress"] as? String else {
            Logger.log.error("Error: Cannot find serverAddress in options")
            return
        }
        Logger.log.info("Using server address \(serverAddress)")

        guard let routeVpn = options!["routeVpn"] as? Bool else {
            Logger.log.error("Error: Cannot find routeVpn in options")
            return
        }

        guard let connected = options!["connected"] as? Bool else {
            Logger.log.error("Error: Cannot find connected in options")
            return
        }

        self.networkInterface = networkInterface
        self.serverAddress = serverAddress
        self.appPolicy = AppPolicy(bypassApps: bypassApps, vpnOnlyApps: vpnOnlyApps, routeVpn: routeVpn, connected: connected)
        
        // Initializing the TrafficManager component
        self.trafficManager = TrafficManagerNIO(interfaceName: networkInterface)
        
        // Whitelist this process in the firewall - error logging happens in function
        guard let groupName = options!["whitelistGroupName"] as? String, setGidForFirewallWhitelist(groupName: groupName) else {
            return
        }

        // Build a rule to match traffic from a subnet and a prefix - default to all protocols (TCP/UDP) and outbound only
        // A nil subnet implies remoteNetwork should be set to nil (which means it'll match all remote networks)
        let subnetRule : (String?, Int) -> NENetworkRule = { (subnet, prefix) in
            return NENetworkRule(
                remoteNetwork: subnet != nil ? NWHostEndpoint(hostname: subnet!, port: "0") : nil,
                remotePrefix: prefix,
                localNetwork: nil,
                localPrefix: 0,
                protocol: .any,
                direction: .outbound
            )
        }

        // Initiating the rules.
        //
        // Only outbound traffic is supported in NETransparentProxyNetworkSettings
        var includedRules:[NENetworkRule] = []
        var excludedRules: [NENetworkRule] = []

        // We want to be "notified" of all flows (TCP and UDP), so we can decide which to manage
        // nil subnet and 0 prefix indicate we want to match everything
        let allNetworks = subnetRule(nil, 0)

        // Exclude IPv4 LAN networks from the proxy
        // We don't need to exclude localhost as this is excluded by default
        let rfc1918NetworkRules = [
            subnetRule("192.168.0.0", 16),
            subnetRule("10.0.0.0", 8),
            subnetRule("172.16.0.0", 12)
        ]

        includedRules.append(allNetworks)
        excludedRules.append(contentsOf: rfc1918NetworkRules)

        // It is unclear what tunnelRemoteAddress means in the case of
        // NETransparentProxy.
        // header file says: NETransparentProxyNetworkSettings are used
        // to communicate the desired network settings for the proxy.
        // Official docs do not know as well:
        // https://developer.apple.com/documentation/networkextension/netunnelnetworksettings/1406032-init
        //
        // Setting it to localhost for now, until a 'proper' solution is found
        let settings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: serverAddress)
        settings.includedNetworkRules = includedRules
        settings.excludedNetworkRules = excludedRules

        // Sending the desired settings to the ProxyExtension process.
        // If the setting are not correct, an error will be thrown.
        self.setTunnelNetworkSettings(settings) { [] error in
            if (error != nil) {
                Logger.log.error("Error: \(error!.localizedDescription) in setTunnelNetworkSettings()")
                completionHandler(error)
                return
            }
            
            // This is needed in order to make the proxy connect.
            // If omitted the proxy will hang in the "Connecting..." state.
            completionHandler(nil)
        }
        
        Logger.log.info("Proxy started!")
    }
    
    // Set the GID of the extension process to the whitelist group (likely "piavpn")
    // This GID is whitelisted by the firewall so we can route packets out
    // the physical interface even when the killswitch is active.
    func setGidForFirewallWhitelist(groupName: String) -> Bool {
        Logger.log.info("Trying to set gid of extension (pid: \(getpid()) at \(getProcessPath(pid: getpid())!) to \(groupName)")
        guard let whitelistGid = getGroupIdFromName(groupName: groupName) else {
            Logger.log.error("Error: unable to get gid for \(groupName) group!")
            return false
        }

        // Setting either the egid or rgid successfully is a success
        guard (setEffectiveGroupID(groupID: whitelistGid) || setRealGroupID(groupID: whitelistGid)) else {
            Logger.log.error("Error: unable to set group to \(groupName) with gid: \(whitelistGid)!")
            return false
        }
        
        Logger.log.info("Should have successfully set gid of extension to \(groupName) with gid: \(whitelistGid)")
        return true
    }
    
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Logger.log.info("Proxy stopped!")
    }
}
