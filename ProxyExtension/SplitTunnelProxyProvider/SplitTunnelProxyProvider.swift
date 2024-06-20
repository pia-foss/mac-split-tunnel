import Foundation
import NetworkExtension

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
// SplitTunnelProxyProvider class to a NEAppProxyProvider and return false
// in handleNewFlow, then verify that no app can connect to the internet.

final class SplitTunnelProxyProvider : NETransparentProxyProvider {

    // The engine
    public var engine: ProxyEngineProtocol!

    // The logger
    public var logger: LoggerProtocol!

    override func startProxy(options: [String : Any]?, completionHandler: @escaping (Error?) -> Void) {
        let logLevel: String = options?["logLevel"] as? String ?? ""
        let logFile: String = options?["logFile"] as? String ?? ""

        self.logger = self.logger ?? Logger.instance

        // Ensure the logger is initialized first
        logger.updateLogger(logLevel: logLevel, logFile: logFile)

        // Contains connection state, routing, interface, and bypass/vpnOnly app information
        guard let vpnState = VpnStateFactory.create(options: options) else {
            log(.error, "provided incorrect list of options. They might be missing or an incorrect type")
            return
        }

        self.engine = self.engine ?? ProxyEngine(vpnState: vpnState, flowHandler: FlowHandler())

        // Whitelist this process in the firewall - error logging happens in function
        guard FirewallWhitelister(groupName: vpnState.whitelistGroupName).whitelist() else {
            return
        }

        // Apply our split tunnel network rules
        // No need to guard this, as it fails via the completionHandler
        SplitTunnelNetworkConfig(serverAddress: vpnState.serverAddress,
                                 provider: self).apply(completionHandler)

        log(.info, "Transparent Proxy started!")
    }

    // MARK: Managing flows
    // handleNewFlow() is called whenever an application
    // creates a new TCP or UDP socket.
    //
    //   return true  ->
    //     The flow of this app will be managed by the network extension
    //   return false ->
    //     The flow of this app will NOT be managed.
    //     It will be routed through the system default network interface
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        return engine.handleNewFlow(flow)
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        engine.handleAppMessage(messageData, completionHandler: completionHandler)
    }

    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log(.info, "Transparent Proxy stopped!")
    }
}
