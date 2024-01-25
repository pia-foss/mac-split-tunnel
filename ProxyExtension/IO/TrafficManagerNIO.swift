import Foundation
import NetworkExtension
import NIO

struct SessionConfig {
    var bindIp: String { interface.ip4()! }
    let interface: NetworkInterfaceProtocol
    // We need to make this optional so that we can
    // leave it nil in tests - tests do not use an EventLoopGroup
    let eventLoopGroup: MultiThreadedEventLoopGroup!
}

// Manage the handling of Proxy Sessions
final class TrafficManagerNIO : TrafficManager {
    var sessionConfig: SessionConfig!
    let proxySessionFactory: ProxySessionFactory
    var idGenerator: IDGenerator

    init(interface: NetworkInterfaceProtocol, proxySessionFactory: ProxySessionFactory = DefaultProxySessionFactory(),
         config: SessionConfig? = nil) {
        // Used to assign unique IDs to each session
        self.idGenerator = IDGenerator()
        self.sessionConfig = config ?? Self.defaultSessionConfig(interface: interface)
        self.proxySessionFactory = proxySessionFactory
    }

    func updateSessionConfig(sessionConfig: SessionConfig) {
        self.sessionConfig = sessionConfig
    }

    deinit {
        try! sessionConfig.eventLoopGroup.syncShutdownGracefully()
    }

    private func nextId() -> IDGenerator.ID {
        idGenerator.generate()
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

    // Fire off a proxy session for each new flow
    func handleFlowIO(_ flow: Flow) {
        if let tcpFlow = flow as? FlowTCP {
            let tcpSession = proxySessionFactory.create(flow: tcpFlow, config: sessionConfig, id: nextId())
            tcpSession.start()
        } else if let udpFlow = flow as? FlowUDP {
            let udpSession = proxySessionFactory.create(flow: udpFlow, config: sessionConfig, id: nextId())
            udpSession.start()
        }
    }
}

