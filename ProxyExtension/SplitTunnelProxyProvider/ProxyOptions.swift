protocol ProxyOptionsFactoryProtocol {
    func create(options: [String : Any]?) -> ProxyOptions?
}

struct ProxyOptionsFactory: ProxyOptionsFactoryProtocol {
    // This function returns a not nil value only if all options are present
    // and are the expected type
    func create(options: [String : Any]?) -> ProxyOptions? {
        var proxyOptions = ProxyOptions()
        guard let bypassApps = options!["bypassApps"] as? [String] else {
            log(.error, "Error: Cannot find bypassApps in options")
            return nil
        }
        proxyOptions.bypassApps = bypassApps
        log(.info, "Managing \(proxyOptions.bypassApps)")

        guard let vpnOnlyApps = options!["vpnOnlyApps"] as? [String] else {
            log(.error, "Error: Cannot find vpnOnlyApps in options")
            return nil
        }
        proxyOptions.vpnOnlyApps = vpnOnlyApps

        guard let networkInterface = options!["networkInterface"] as? String else {
            log(.error, "Error: Cannot find networkInterface in options")
            return nil
        }
        proxyOptions.networkInterface = networkInterface
        log(.info, "Sending flows to interface \(proxyOptions.networkInterface)")

        guard let serverAddress = options!["serverAddress"] as? String else {
            log(.error, "Error: Cannot find serverAddress in options")
            return nil
        }
        proxyOptions.serverAddress = serverAddress
        log(.info, "Using server address \(proxyOptions.serverAddress)")

        guard let routeVpn = options!["routeVpn"] as? Bool else {
            log(.error, "Error: Cannot find routeVpn in options")
            return nil
        }
        proxyOptions.routeVpn = routeVpn

        guard let connected = options!["connected"] as? Bool else {
            log(.error, "Error: Cannot find connected in options")
            return nil
        }
        proxyOptions.connected = connected

        guard let groupName = options!["whitelistGroupName"] as? String else {
            log(.error, "Error: Cannot find whitelistGroupName in options")
            return nil
        }
        proxyOptions.groupName = groupName

        return proxyOptions
    }
}

struct ProxyOptions {
    var bypassApps: [String] = []
    var vpnOnlyApps: [String] = []
    var networkInterface: String = ""
    var serverAddress: String = ""
    var routeVpn: Bool = false
    var connected: Bool = false
    var groupName: String = ""
}
