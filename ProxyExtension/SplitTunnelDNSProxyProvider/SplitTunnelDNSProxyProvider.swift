import Foundation
import NetworkExtension

final class SplitTunnelDNSProxyProvider : NEDNSProxyProvider {
    
    public var flowHandler: FlowHandlerProtocol!
    public var vpnState: VpnState!
    
    // The logger
    public var logger: LoggerProtocol!
    
    override func startProxy(options:[String: Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
        let logLevel: String = options?["logLevel"] as? String ?? ""
        let logFile: String = options?["logFile"] as? String ?? ""

        self.logger = self.logger ?? Logger.instance

        // Ensure the logger is initialized first
        logger.updateLogger(logLevel: logLevel, logFile: logFile)
        
        // init just once, set up swiftNIO event loop
        self.flowHandler = FlowHandler()
        
        var options = [
            "bypassApps" : ["/usr/bin/curl", "org.mozilla.firefox"],
            "vpnOnlyApps" : [],
            "bindInterface" : "en0",
            "serverAddress" : "127.0.0.1",
            "logFile" : "/tmp/STProxy.log",
            "logLevel" : "debug",
            "routeVpn" : true,
            "isConnected" : true,
            "whitelistGroupName" : "piavpn"
        ] as [String : Any]
        guard let vpnState2 = VpnStateFactory.create(options: options) else {
            log(.error, "provided incorrect list of options. They might be missing or an incorrect type")
            return
        }
        vpnState = vpnState2
        
        completionHandler(nil)
    }

    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    // Be aware that by returning false in NEDNSProxyProvider handleNewFlow(),
    // the flow is discarded and the connection is closed.
    // This is similar to how NEAppProxyProvider works, compared to what we use
    // for traffic Split Tunnel which is NETransparentProxyProvider.
    // This means that we need to handle ALL DNS requests when DNS Split Tunnel
    // is enabled, even for non-managed apps.
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        var appName = flow.sourceAppSigningIdentifier
        if appName == "com.apple.nslookup" || appName == "com.apple.curl" {
            flowHandler.startProxySession(flow: flow, vpnState: vpnState)
            return true
        } else {
            return false
        }
    }
}
