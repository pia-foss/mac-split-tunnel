import Foundation
import NetworkExtension
import NIO

struct SessionConfig {
    // We need to make this optional so that we can
    // leave it nil in tests - tests do not use an EventLoopGroup
    // Instead they just use an EmbeddedEventLoop
    let eventLoopGroup: MultiThreadedEventLoopGroup!
    let interfaceAddress: String
}

final class TrafficManagerNIO : TrafficManager {
    let sessionConfig: SessionConfig!
    let proxySessionFactory: ProxySessionFactory
    var idGenerator: IDGenerator

    init(interfaceName: String, proxySessionFactory: ProxySessionFactory = DefaultProxySessionFactory(), 
         config: SessionConfig? = nil) {
        // Used to assign unique IDs to each session
        self.idGenerator = IDGenerator()
        self.sessionConfig = config ?? Self.defaultSessionConfig(interfaceName: interfaceName)

        self.proxySessionFactory = proxySessionFactory
    }

    deinit {
        try! sessionConfig.eventLoopGroup.syncShutdownGracefully()
    }

    private func nextId() -> IDGenerator.ID {
        idGenerator.generate()
    }

    private static func defaultSessionConfig(interfaceName: String) -> SessionConfig {
        // Fundamental config used to establish a session
        SessionConfig(
            // Trying with just 1 thread for now, since we dont want to use too many resources on the user's machines.
            // According to SwiftNIO docs it is better to use MultiThreadedEventLoopGroup
            // even in the case of just 1 thread
            eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1),
            interfaceAddress: getNetworkInterfaceIP(interfaceName: interfaceName)!
        )
    }

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

