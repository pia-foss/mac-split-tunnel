import Foundation
import NetworkExtension

func handleError(_ error: Error?, _ operation: String, _ flow: NEAppProxyFlow, _ socket: Socket) {
    // We close both the flow and the connection when:
    // - Any I/O operation return an error
    // - We read or write 0 data to a flow
    // - We read or write 0 data to a socket
    
    // Filtering out socket readNoData and writeNoData for consistencies with flows
    var filteredError = error
    if let socketError = error as? SocketError, (socketError == .readNoData || socketError == .writeNoData) {
        filteredError = nil
    }
    if filteredError != nil {
        Logger.log.error("Error: \(socket.appID) \"\(error!.localizedDescription)\" during operation: \(operation) in fd: \(socket.fileDescriptor)")
    } else {
        Logger.log.warning("Warning: \(socket.appID) Empty data buffer during operation: \(operation) in fd: \(socket.fileDescriptor)")
    }
    Logger.log.warning("Warning: \(socket.appID) Closing both flow and socket after operation: \(operation) in fd: \(socket.fileDescriptor)")
    socket.close()
    closeFlow(flow)
}

func closeFlow(_ flow: NEAppProxyFlow) {
    // close the flow when you dont want to read and write to it anymore
    flow.closeReadWithError(nil)
    flow.closeWriteWithError(nil)
}
