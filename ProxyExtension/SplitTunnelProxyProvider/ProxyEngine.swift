import Foundation
import NIO
import NetworkExtension

protocol ProxyEngineProtocol {
    var vpnState: VpnState { get set }

    func handleNewFlow(_ flow: Flow) -> Bool
    func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?)
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
        messageHandler.handleAppMessage(messageData, completionHandler) { (messageType, newVpnState) in
            switch messageType {
            case .VpnStateUpdateMessage:
                self.vpnState = newVpnState
            }
        }
    }
}
