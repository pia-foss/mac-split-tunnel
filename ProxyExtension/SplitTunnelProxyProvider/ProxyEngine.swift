import Foundation
import NIO
import NetworkExtension

protocol ProxyEngineProtocol {
    var vpnState: VpnState { get set }

    func handleNewFlow(_ flow: Flow) -> Bool
    func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?)
}

// Manages core functionality of the Split Tunnel
// * handles flows
// * handles app messages which may modify Split Tunnel behaviour (i.e changing bypass/vpnOnly apps)
final class ProxyEngine: ProxyEngineProtocol {
    var vpnState: VpnState

    public var flowHandler: FlowHandlerProtocol
    public var messageHandler: MessageHandlerProtocol

    init(vpnState: VpnState) {
        self.vpnState = vpnState
        self.flowHandler = FlowHandler()
        self.messageHandler = MessageHandler()
    }

    public func handleNewFlow(_ flow: Flow) -> Bool {
        flowHandler.handleNewFlow(flow, vpnState: vpnState)
    }

    public func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        messageHandler.handleAppMessage(messageData, completionHandler) { (messageType) in
            switch messageType {
            case .VpnStateUpdateMessage(let newVpnState):
                self.vpnState = newVpnState
            }
        }
    }
}
