import Foundation
import NetworkExtension
import os.log
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

// Given a group name (i.e "piavpn") return the associated GID
func getGroupIdByName(groupName: String) -> gid_t? {
    return groupName.withCString { cStringGroupName in
        var result: gid_t?
        var groupEntry = group()
        var buffer: [Int8] = Array(repeating: 0, count: 1024)
        var tempPointer: UnsafeMutablePointer<group>?

        getgrnam_r(cStringGroupName, &groupEntry, &buffer, buffer.count, &tempPointer)

        if let _ = tempPointer {
            result = groupEntry.gr_gid
        }

        return result
    }
}

func setEffectiveGroupID(groupID: gid_t) -> Bool {
    // setegid returns 0 on success, -1 on failure
    return setegid(groupID) == 0
}

func setRealGroupID(groupID: gid_t) -> Bool {
    // setgid returns 0 on success, -1 on failure
    return setgid(groupID) == 0
}

class STProxyProvider : NETransparentProxyProvider {
    
    // MARK: Proxy Properties
    var appsToManage: [String]?
    var networkInterface: String?
    var serverAddress: String?

    // Set the GID of the extension process to the piavpn group
    // This GID is whitelisted by the firewall so we can route packets out
    // the physical interface even when the killswitch is active.
    func setGidForFirewallWhitelist() {
        Logger.log.info("Trying to set gid of extension to piavpn")
        if let piavpnGid = getGroupIdByName(groupName: "piavpn") {
            if(!setEffectiveGroupID(groupID: piavpnGid) && !setRealGroupID(groupID: piavpnGid)) {
                Logger.log.error("Error: unable to set group to piavpn!")
            }
            else {
                Logger.log.info("Should have successfully set gid of extension to piavpn")
            }
        }
        else {
            Logger.log.error("Error: unable to get gid for piavpn group!")
        }
    }

    override init() {
        super.init()
        // Whitelist this process in the firewall
        setGidForFirewallWhitelist()
    }
    
    // MARK: Proxy Functions
    override func startProxy(options: [String : Any]?, completionHandler: @escaping (Error?) -> Void) {
        // Initialize the logger first
        guard let logLevelString = options!["logLevel"] as? String else {
            return
        }

        let console = ConsoleLogger(Bundle.main.bundleIdentifier! + ".console", logLevel: logLevelFromString(logLevelString))
        Logger.log.add(console)

        guard let logFile = options!["logFile"] as? String else {
            Logger.log.error("cannot find logFile in options")
            return
        }
        
        let fileURL = URL(fileURLWithPath: logFile).absoluteURL

        do {
            let file = try FileLogger("com.privateinternetaccess.splittunnel.poc.extension.systemextension.logfile",
                                  logLevel: logLevelFromString(logLevelString),
                                  fileURL: fileURL,
                                  filePermission: "777")
            Logger.log.add(file)
        }
        catch {
            Logger.log.warning("Could not start File Logger, will log only to console.")
        }
        Logger.log.info("######################################################\n######################################################\nLogger initialized. Writing to \(fileURL)")

        // Checking that all the required settings have been passed to the
        // extension by the ProxyApp
        guard let appsToManage = options!["appsToManage"] as? [String] else {
            Logger.log.error("Error: Cannot find appsToManage in options")
            return
        }
        Logger.log.info("Managing \(appsToManage)")
        
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

        self.appsToManage = appsToManage
        self.networkInterface = networkInterface
        self.serverAddress = serverAddress
        
        // Initiating the rules.
        // We want to be "notified" of all flows, so we can decide which to manage,
        // based on the flow's app name.
        //
        // Only outbound traffic is supported in NETransparentProxyNetworkSettings
        var rules:[NENetworkRule] = []
        let ruleAllTCP = NENetworkRule(remoteNetwork: nil, remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .TCP, direction: .outbound)
        let ruleAllUDP = NENetworkRule(remoteNetwork: nil, remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .UDP, direction: .outbound)
        rules.append(ruleAllTCP)
        rules.append(ruleAllUDP)

        // It is unclear what tunnelRemoteAddress means in the case of
        // NETransparentProxy.
        // header file says: NETransparentProxyNetworkSettings are used
        // to communicate the desired network settings for the proxy.
        // Official docs do not know as well:
        // https://developer.apple.com/documentation/networkextension/netunnelnetworksettings/1406032-init
        //
        // Setting it to localhost for now, until a 'proper' solution is found
        let settings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: serverAddress)
        settings.includedNetworkRules = rules
        settings.excludedNetworkRules = nil

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
    
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Logger.log.info("Proxy stopped!")
    }
    
    func logLevelFromString(_ levelString: String) -> LogLevel {
        switch levelString.lowercased() {
        case "debug":
            return .debug
        case "info":
            return .info
        case "warning":
            return .warning
        case "error":
            return .error
        default:
            return .error
        }
    }
}
