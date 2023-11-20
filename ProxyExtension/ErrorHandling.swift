import Foundation
import NetworkExtension
import os.log

func handleError(_ error: Error?, _ operation: String, _ flow: NEAppProxyFlow, _ socket: Socket) {
    // We close both the flow and the connection when:
    // - Any I/O operation return an error
    // - We read or write 0 data to a flow
    // - We read or write 0 data to a socket
    if error != nil {
        os_log("error during %s: %s", operation, error.debugDescription)
    } else {
        os_log("read no data from %s", operation)
    }
    socket.close()
    closeFlow(flow)
}

func closeFlow(_ flow: NEAppProxyFlow) {
    // close the flow when you dont want to read and write to it anymore
    flow.closeReadWithError(nil)
    flow.closeWriteWithError(nil)
}
