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

final class STProxyProvider : NETransparentProxyProvider {

    // MARK: Proxy options
    var bypassApps: [String]
    var vpnOnlyApps: [String]
    var networkInterface: String
    var serverAddress: String
    var routeVpn: Bool
    var connected: Bool
    var groupName: String
    
    // MARK: Proxy components
    // The lazy initialization is triggered when the
    // component is first accessed.
    // At that point we should have already set the proxy
    // options.
    // It is difficult to inject a different type for these
    // components, since we don't control either when
    // init() or startProxy() are called.
    // (We could use the options array, but it sounds janky)
    lazy var appPolicy: AppPolicy = {
        return AppPolicy(bypassApps: bypassApps, vpnOnlyApps: vpnOnlyApps, routeVpn: routeVpn, connected: connected)
    }()
    lazy var trafficManager: TrafficManager = {
        return TrafficManagerNIO(interfaceName: networkInterface)
    }()

    // MARK: Proxy Functions
    override init() {
        bypassApps = []
        vpnOnlyApps = []
        networkInterface = ""
        serverAddress = ""
        routeVpn = false
        connected = false
        groupName = ""
        super.init()
    }
    
    override func startProxy(options: [String : Any]?, completionHandler: @escaping (Error?) -> Void) {
        let logLevel: String = options?["logLevel"] as? String ?? "error"
        let logFile: String = options?["logFile"] as? String ?? "/tmp/STProxy.log"
        
        // Ensure the logger is initialized
        guard initializeLogger(logLevel: logLevel, logFile: logFile) else {
            return
        }
        
        guard setProxyOptions(options: options) else {
            return
        }
        
        // Whitelist this process in the firewall - error logging happens in function
        guard setGidForFirewallWhitelist(groupName: groupName) else {
            return
        }

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

        self.setTunnelNetworkSettings(settings) { [] error in
            if (error != nil) {
                log(.error, "\(error!.localizedDescription) when setting proxy settings")
                completionHandler(error)
                return
            }
            
            // This is needed in order to make the proxy connect.
            // If omitted the proxy will hang in the "Connecting..." state
            completionHandler(nil)
        }
        
        log(.info, "Proxy started!")
    }
    
    // This function returns true only if all options are present
    // and are the expected type
    func setProxyOptions(options: [String : Any]?) -> Bool {
        // Checking that all the required settings have been passed
        // to the extension
        guard let _bypassApps = options!["bypassApps"] as? [String] else {
            log(.error, "Error: Cannot find bypassApps in options")
            return false
        }
        bypassApps = _bypassApps
        log(.info, "Managing \(bypassApps)")

        guard let _vpnOnlyApps = options!["vpnOnlyApps"] as? [String] else {
            log(.error, "Error: Cannot find vpnOnlyApps in options")
            return false
        }
        vpnOnlyApps = _vpnOnlyApps

        guard let _networkInterface = options!["networkInterface"] as? String else {
            log(.error, "Error: Cannot find networkInterface in options")
            return false
        }
        networkInterface = _networkInterface
        log(.info, "Sending flows to interface \(networkInterface)")

        guard let _serverAddress = options!["serverAddress"] as? String else {
            log(.error, "Error: Cannot find serverAddress in options")
            return false
        }
        serverAddress = _serverAddress
        log(.info, "Using server address \(serverAddress)")

        guard let _routeVpn = options!["routeVpn"] as? Bool else {
            log(.error, "Error: Cannot find routeVpn in options")
            return false
        }
        routeVpn = _routeVpn

        guard let _connected = options!["connected"] as? Bool else {
            log(.error, "Error: Cannot find connected in options")
            return false
        }
        connected = _connected
        
        guard let _groupName = options!["whitelistGroupName"] as? String else {
            log(.error, "Error: Cannot find whitelistGroupName in options")
            return false
        }
        groupName = _groupName
        
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
    // ** ADD A BUILD RULE FUNCTION
    
    // Set the GID of the extension process to the whitelist group (likely "piavpn")
    // This GID is whitelisted by the firewall so we can route packets out
    // the physical interface even when the killswitch is active.
    func setGidForFirewallWhitelist(groupName: String) -> Bool {
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
    
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log(.info, "Proxy stopped!")
    }
}
