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
// SplitTunnelProxyProvider class to a NEAppProxyProvider and return false
// in handleNewFlow, then verify that no app can connect to the internet.

final class SplitTunnelProxyProvider : NETransparentProxyProvider {

    // MARK: Proxy options
    public var vpnStateFactory: VpnStateFactoryProtocol!

    // The engine
    public var engine: ProxyEngineProtocol!

    // The logger
    public var logger: LoggerProtocol!

    override func startProxy(options: [String : Any]?, completionHandler: @escaping (Error?) -> Void) {
        let logLevel: String = options?["logLevel"] as? String ?? "error"
        let logFile: String = options?["logFile"] as? String ?? "/tmp/STProxy.log"

        self.logger = self.logger ?? Logger.instance
        self.vpnStateFactory = self.vpnStateFactory ?? VpnStateFactory()

        // Ensure the logger is initialized first
        guard logger.initializeLogger(logLevel: logLevel, logFile: logFile) else {
            return
        }

        // Contains connection state, routing, interface, and bypass/vpnOnly app information
        guard let vpnState = vpnStateFactory.create(options: options) else {
            log(.error, "provided incorrect list of options. They might be missing or an incorrect type")
            return
        }

        let trafficManager = TrafficManagerNIO(interface: NetworkInterface(interfaceName: vpnState.networkInterface))
        self.engine = self.engine ?? ProxyEngine(trafficManager: trafficManager, vpnState: vpnState)

        // Whitelist this process in the firewall - error logging happens in function
        guard engine.whitelistProxyInFirewall(groupName: vpnState.groupName) else {
            log(.error, "failed to set gid")
            return
        }

        engine.setTunnelNetworkSettings(serverAddress: vpnState.serverAddress, provider: self, completionHandler: completionHandler)

        log(.info, "Proxy started!")
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
    
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log(.info, "Proxy stopped!")
    }
}
