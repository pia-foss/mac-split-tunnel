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

    public var flowHandler: FlowHandler
    public var messageHandler: MessageHandler

    init(vpnState: VpnState) {
        self.vpnState = vpnState
        self.flowHandler = FlowHandler()
        self.messageHandler = MessageHandler()
    }

    public func handleNewFlow(_ flow: Flow) -> Bool {
        flowHandler.handleNewFlow(flow, vpnState: vpnState)
    }

    public func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        messageHandler.handleAppMessage(messageData, completionHandler: completionHandler) { (messageType, newVpnState) in
            switch messageType {
            case .VpnStateUpdateMessage:
                self.vpnState = newVpnState
            }
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
