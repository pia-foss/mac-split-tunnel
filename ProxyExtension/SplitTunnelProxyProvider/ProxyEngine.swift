import Foundation
import NIO
import NetworkExtension

protocol ProxyEngineProtocol {
    var vpnState: VpnState { get set }

    func handleNewFlow(_ flow: Flow) -> Bool
    func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?)
}

struct SessionConfig {
    var bindIp: String { interface.ip4()! }
    let interface: NetworkInterfaceProtocol
    // We need to make this optional so that we can
    // leave it nil in tests - tests do not use an EventLoopGroup
    let eventLoopGroup: MultiThreadedEventLoopGroup!
}

// Manages core functionality of the Split Tunnel
// * handles new flows
// *
final class ProxyEngine: ProxyEngineProtocol {
    var vpnState: VpnState

    var sessionConfig: SessionConfig!
    let proxySessionFactory: ProxySessionFactory

    init(vpnState: VpnState, proxySessionFactory: ProxySessionFactory = DefaultProxySessionFactory(),
         config: SessionConfig? = nil) {
        self.vpnState = vpnState

        self.sessionConfig = config ?? Self.defaultSessionConfig(interface: NetworkInterface(interfaceName: vpnState.networkInterface))
        self.proxySessionFactory = proxySessionFactory
    }

    deinit {
        if sessionConfig.eventLoopGroup != nil {
            try! sessionConfig.eventLoopGroup.syncShutdownGracefully()
        }
    }

    public func handleNewFlow(_ flow: Flow) -> Bool {
        NewFlowHandler(vpnState: vpnState, proxySessionFactory: proxySessionFactory, config: sessionConfig).handleNewFlow(flow)
    }

    public func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Deserialization
        if let options = try? JSONSerialization.jsonObject(with: messageData, options: []) as? [String: Any] {
            log(.info, String(decoding: messageData, as: UTF8.self))
            // Contains connection state, routing, interface, and bypass/vpnOnly app information
            guard let vpnState = VpnStateFactory.create(options: options) else {
                log(.error, "provided incorrect list of options. They might be missing or an incorrect type")
                completionHandler?("bad_options_error".data(using: .utf8))
                return
            }
            // TODO: The API is changing. Make sure we update the target interface in the traffic manager.
            // engine.trafficManager.updateInterface(vpnState.networkInterface)
            self.vpnState = vpnState

            log(.info, "Proxy updated!")
            // Optionally send a response back to the app
            completionHandler?("ok".data(using: .utf8))
        }
        else {
            log(.info, "Failed to deserialize data")
            completionHandler?("deserialization_error".data(using: .utf8))
        }
    }

    private static func defaultSessionConfig(interface: NetworkInterfaceProtocol) -> SessionConfig {
        // Fundamental config used to establish a session
        SessionConfig(
            interface: interface,
            // Trying with just 1 thread for now, since we dont want to use too many resources on the user's machines.
            // According to SwiftNIO docs it is better to use MultiThreadedEventLoopGroup
            // even in the case of just 1 thread
            eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1)
        )
    }
}
