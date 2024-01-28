import Foundation

protocol MessageHandlerProtocol {
    func handleAppMessage(_ messageData: Data, _ completionHandler: ((Data?) -> Void)?,
                          onProcessedMessage: @escaping (MessageType) -> Void)
}

enum MessageType {
    case VpnStateUpdateMessage(VpnState)
}

// Responsible for handling incoming messages from the 'driver app'
// aka the app that started the proxy
final class MessageHandler: MessageHandlerProtocol {
    public func handleAppMessage(_ messageData: Data, _ completionHandler: ((Data?) -> Void)?,
                                 onProcessedMessage: (MessageType) -> Void) {
        // Deserialization
        if let options = try? JSONSerialization.jsonObject(with: messageData, options: []) as? [String: Any] {
            log(.info, String(decoding: messageData, as: UTF8.self))
            // Contains connection state, routing, interface, and bypass/vpnOnly app information
            guard let newVpnState = VpnStateFactory.create(options: options) else {
                log(.error, "provided incorrect list of options. They might be missing or an incorrect type")
                completionHandler?("bad_options_error".data(using: .utf8))
                return
            }
            // TODO: The API is changing. Make sure we update the target interface in the traffic manager.
            // engine.trafficManager.updateInterface(vpnState.networkInterface)

            onProcessedMessage(.VpnStateUpdateMessage(newVpnState))

            log(.info, "Proxy updated!")
            // Optionally send a response back to the app
            completionHandler?("ok".data(using: .utf8))
        }
        else {
            log(.info, "Failed to deserialize data")
            completionHandler?("deserialization_error".data(using: .utf8))
        }
    }
}
