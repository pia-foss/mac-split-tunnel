// Responsible for validating and creating VpnState instances
struct VpnStateFactory {
    // This function returns a not nil value only if all options are present
    // and are the expected type
    static func create(options: [String : Any]?) -> VpnState? {
        var vpnState = VpnState()

        // Set logging-related fields - default to empty strings if not defined
        // empty strings are handled inside the Logger initializer which cause fallbacks
        // to defaults defined by that class
        let logLevel = options!["logLevel"] as? String ?? ""
        let logFile = options!["logFile"] as? String ?? ""
        vpnState.logLevel = logLevel
        vpnState.logFile = logFile

        guard let bypassApps = options!["bypassApps"] as? [String] else {
            log(.error, "Error: Cannot find bypassApps in options")
            return nil
        }
        // Normalize by making all the app descriptors lower case
        vpnState.bypassApps = bypassApps.map { $0.lowercased() }
        log(.info, "Managing bypass apps: \(vpnState.bypassApps)")

        guard let vpnOnlyApps = options!["vpnOnlyApps"] as? [String] else {
            log(.error, "Error: Cannot find vpnOnlyApps in options")
            return nil
        }
        // Normalize by making all the app descriptors lower case
        vpnState.vpnOnlyApps = vpnOnlyApps.map { $0.lowercased() }
        log(.info, "Managing vpnOnly apps: \(vpnState.vpnOnlyApps)")

        guard let bindInterface = options!["bindInterface"] as? String else {
            log(.error, "Error: Cannot find bindInterface in options")
            return nil
        }
        vpnState.bindInterface = bindInterface
        log(.info, "bindInterface: \(vpnState.bindInterface)")

        guard let serverAddress = options!["serverAddress"] as? String else {
            log(.error, "Error: Cannot find serverAddress in options")
            return nil
        }
        vpnState.serverAddress = serverAddress
        log(.info, "Using server address \(vpnState.serverAddress)")

        guard let routeVpn = options!["routeVpn"] as? Bool else {
            log(.error, "Error: Cannot find routeVpn in options")
            return nil
        }
        log(.info, "routeVPN: \(routeVpn)")
        vpnState.routeVpn = routeVpn

        guard let isConnected = options!["isConnected"] as? Bool else {
            log(.error, "Error: Cannot find isConnected in options")
            return nil
        }
        vpnState.isConnected = isConnected
        log(.info, "isConnected: \(isConnected)")
        
        guard let dnsFollowAppRules = options!["dnsFollowAppRules"] as? Bool else {
            log(.error, "Error: Cannot find dnsFollowAppRules in options")
            return nil
        }
        vpnState.dnsFollowAppRules = dnsFollowAppRules
        log(.info, "dnsFollowAppRules: \(dnsFollowAppRules)")

        guard let whitelistGroupName = options!["whitelistGroupName"] as? String else {
            log(.error, "Error: Cannot find whitelistGroupName in options")
            return nil
        }
        vpnState.whitelistGroupName = whitelistGroupName
        log(.info, "whitelistGroupName: \(whitelistGroupName)")

        return vpnState
    }
}

// Represents the state received from the daemon
struct VpnState: Equatable {
    var logFile: String = ""
    var logLevel: String = ""
    var bypassApps: [String] = []
    var vpnOnlyApps: [String] = []
    var bindInterface: String = ""
    var serverAddress: String = ""
    var routeVpn: Bool = false
    var isConnected: Bool = false
    var dnsFollowAppRules: Bool = false
    var whitelistGroupName: String = ""
}
