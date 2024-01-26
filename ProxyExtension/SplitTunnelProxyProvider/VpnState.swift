protocol VpnStateFactoryProtocol {
    func create(options: [String : Any]?) -> VpnState?
}

// Responsible for validating and creating VpnState instances
struct VpnStateFactory: VpnStateFactoryProtocol {
    // This function returns a not nil value only if all options are present
    // and are the expected type
    func create(options: [String : Any]?) -> VpnState? {
        var vpnState = VpnState()
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
        vpnState.vpnOnlyApps = vpnOnlyApps.map { $0.lowercased() }
        log(.info, "Managing vpnOnly apps: \(vpnState.vpnOnlyApps)")

        guard let networkInterface = options!["bindInterface"] as? String else {
            log(.error, "Error: Cannot find networkInterface in options")
            return nil
        }
        vpnState.networkInterface = networkInterface
        log(.info, "Sending flows to interface \(vpnState.networkInterface)")

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

        guard let connected = options!["isConnected"] as? Bool else {
            log(.error, "Error: Cannot find connected in options")
            return nil
        }
        vpnState.connected = connected
        log(.info, "connected: \(connected)")

        guard let groupName = options!["whitelistGroupName"] as? String else {
            log(.error, "Error: Cannot find whitelistGroupName in options")
            return nil
        }
        vpnState.groupName = groupName

        return vpnState
    }
}

// Represents the state received from the daemon
struct VpnState {
    var bypassApps: [String] = []
    var vpnOnlyApps: [String] = []
    var networkInterface: String = ""
    var serverAddress: String = ""
    var routeVpn: Bool = false
    var connected: Bool = false
    var groupName: String = ""
}
