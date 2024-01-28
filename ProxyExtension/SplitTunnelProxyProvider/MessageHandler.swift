//
//  MessageHandler.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 26/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

enum MessageType {
    case VpnStateUpdateMessage
}

final class MessageHandler {
    public func handleAppMessage(_ messageData: Data, _ completionHandler: ((Data?) -> Void)?,
                                 onProcessedMessage: (MessageType, VpnState) -> Void) {
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

            onProcessedMessage(.VpnStateUpdateMessage, vpnState)

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
