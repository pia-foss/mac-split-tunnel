import Foundation

final class MockMessageHandler: MessageHandlerProtocol, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    let newVpnState: VpnState

    // Allow injection of an new VpnState - we don't implement all the machinery
    // of converting the json to a VpnState instead we just return the passed-in newVpnState
    // this is sufficient for testing the collaborators.
    init(newVpnState: VpnState) {
        self.newVpnState = newVpnState
    }

    // Required by MessageHandler
    func handleAppMessage(_ messageData: Data, _ completionHandler: ((Data?) -> Void)?, onProcessedMessage: @escaping (MessageType) -> Void) {
        record(args: [messageData, completionHandler as Any, onProcessedMessage])
        onProcessedMessage(.VpnStateUpdateMessage(newVpnState))
    }
}
