import Foundation
import NetworkExtension

final class SplitTunnelDNSProxyProvider : NEDNSProxyProvider {

    // The engine
    public var engine: ProxyEngineProtocol!

    // The logger
    public var logger: LoggerProtocol!

    override func startProxy(options: [String: Any]? , completionHandler: @escaping (Error?) -> Void) {
        let logLevel: String = options?["logLevel"] as? String ?? ""
        let logFile: String = options?["logFile"] as? String ?? ""

        self.logger = self.logger ?? Logger.instance

        // Ensure the logger is initialized first.
        // May be redundant
        logger.updateLogger(logLevel: logLevel, logFile: logFile)

        // assume the option array is passed when the DNS proxy is started
        // or it's shared with the transparent proxy
        let _options = [
            "bypassApps" : ["com.apple.nslookup", "com.apple.curl", "com.apple.ping"],
            "vpnOnlyApps" : [],
            "bindInterface" : "en0",
            "serverAddress" : "127.0.0.1",
            // do we want to use the same log file or a different one?
            "logFile" : "/tmp/STProxy.log",
            "logLevel" : "debug",
            "routeVpn" : true,
            "isConnected" : true,
            "dnsFollowAppRules": true,
            "whitelistGroupName" : "piavpn"
        ] as [String : Any]
        guard let vpnState = VpnStateFactory.create(options: _options) else {
            log(.error, "provided incorrect list of options. They might be missing or an incorrect type")
            return
        }

        // Right now we do not share the engine with the transparent proxy.
        // This means we will have 2 SwiftNIO event loops and that both proxies are indipendent of eachother.
        // This can be refactored later if the DNS proxy never runs when the transparent proxy is off
        self.engine = self.engine ?? ProxyEngine(vpnState: vpnState, flowHandler: DnsFlowHandler())

        // Whitelist this process in the firewall - error logging happens in function.
        // May be redundant
        guard FirewallWhitelister(groupName: vpnState.whitelistGroupName).whitelist() else {
            return
        }

        completionHandler(nil)
        log(.info, "DNS Proxy started!")
    }

    // Be aware that by returning false in NEDNSProxyProvider handleNewFlow(),
    // the flow is discarded and the connection is closed.
    // This is similar to how NEAppProxyProvider works, compared to what we use
    // for traffic Split Tunnel which is NETransparentProxyProvider.
    // This means that we need to handle the DNS requests of ALL apps
    // when DNS Split Tunnel is enabled
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        return engine.handleNewFlow(flow)
    }

    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log(.info, "DNS Proxy stopped!")
    }
}
