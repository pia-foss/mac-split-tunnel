import Foundation
import NetworkExtension
import NIO

struct SessionConfig {
    let eventLoopGroup: MultiThreadedEventLoopGroup
    let interfaceAddress: String
}

final class TrafficManagerNIO : TrafficManager {
    let sessionConfig: SessionConfig
    var idGenerator: IDGenerator

    init(interfaceName: String) {
        // Used to assign unique IDs to each session
        idGenerator = IDGenerator()
        // Fundamental config used to establish a session
        sessionConfig = SessionConfig(
            // Trying with just 1 thread for now, since we dont want to use too many resources on the user's machines.
            // According to SwiftNIO docs it is better to use MultiThreadedEventLoopGroup
            // even in the case of just 1 thread
            eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1),
            interfaceAddress: getNetworkInterfaceIP(interfaceName: interfaceName)!
        )
    }

    deinit {
        try! sessionConfig.eventLoopGroup.syncShutdownGracefully()
    }

    private func nextId() -> IDGenerator.ID {
        idGenerator.generate()
    }

    // Drop a flow by closing it
    // We use a class method (rather than a static method) so we can call it using `Self`.
    // We also call this method from outside this class.
    static func dropFlow(flow: NEAppProxyFlow) -> Void {
        let error = NSError(domain: "com.privateinternetaccess.vpn", code: 100, userInfo: nil)
        flow.closeReadWithError(error)
        flow.closeWriteWithError(error)
    }

    static func terminateProxySession(flow: NEAppProxyFlow, channel: Channel) -> Void {
        dropFlow(flow: flow)
        // Ensure we execute the close in the same event loop as the channel
        channel.eventLoop.execute {
            guard channel.isActive else {
                return
            }
            channel.close().whenFailure { error in
                // Not much we can do here other than trace it
                log(.error, "Failed to close the channel: \(error)")
            }
        }
    }

    static func terminateProxySession(flow: NEAppProxyFlow, context: ChannelHandlerContext) -> Void {
        dropFlow(flow: flow)
        // Ensure we execute the close in the same event loop as the channel
        context.eventLoop.execute {
            guard context.channel.isActive else {
                return
            }
            context.close().whenFailure { error in
                // Not much we can do here other than trace it
                log(.error, "Failed to close the channel: \(error)")
            }
        }
    }

    // MARK: Public instance methods
    func handleFlowIO(_ flow: NEAppProxyFlow) {
        if let tcpFlow = flow as? NEAppProxyTCPFlow {
            ProxySessionTCP(flow: tcpFlow, sessionConfig: sessionConfig, id: nextId()).start()
        } else if let udpFlow = flow as? NEAppProxyUDPFlow {
            ProxySessionUDP(flow: udpFlow, sessionConfig: sessionConfig, id: nextId()).start()
        }
    }
}
