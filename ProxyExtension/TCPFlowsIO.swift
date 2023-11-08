import Foundation
import NetworkExtension
import os.log

@available(macOS 11.0, *)
extension STProxyProvider {
    func readTCPFlowData(_ tcpFlow: NEAppProxyTCPFlow, _ socket: Socket) {
        // If data has a length of 0 then no data can be subsequently read from the flow.
        // The completion handler is only called for the single read operation that was
        // initiated by calling this method.
        //
        // If the caller wants to read more data then it should call this method again
        // to schedule another read operation and another execution of the
        // completion handler block.
        // Reading the application OUTBOUND traffic
        // This call is blocking: until some data is read the closure will not be called
        tcpFlow.readData { dataReadFromFlow, flowError in
            if flowError == nil, let dataToWriteToSocket = dataReadFromFlow, !dataToWriteToSocket.isEmpty {
                // Writing to the real endpoint (via the local socket) the application OUTBOUND traffic
                if socket.status == .closed {
                    self.closeFlow(tcpFlow)
                    return
                }
                socket.writeData(dataToWriteToSocket, completionHandler: { socketError in
                    if socketError == nil {
                        // wait for answer from the endpoint
                        self.writeTCPFlowData(tcpFlow, socket)
                        self.readTCPFlowData(tcpFlow, socket)
                    } else { // handling errors for socket send()
                        os_log("error during socket writeData! %s", socketError.debugDescription)
                        socket.closeConnection()
                        self.closeFlow(tcpFlow)
                    }
                })
            } else { // handling errors for flow readData()
                if flowError != nil {
                    os_log("error during flow read! %s", flowError.debugDescription)
                } else { // is reading 0 data from a flow different than getting an error? (verify this!)
                    os_log("read no data from flow readData()")
                }
                // no op: We stop calling readTCPFlowData(), ending the recursive loop
                socket.closeConnection()
                self.closeFlow(tcpFlow)
            }
        }
    }
    
    func writeTCPFlowData(_ tcpFlow: NEAppProxyTCPFlow, _ socket: Socket) {
        if socket.status == .closed {
            self.closeFlow(tcpFlow)
            return
        }
        // This call is blocking: until some data is read the closure will not be called
        Task.detached(priority: .background) {
            socket.readData(completionHandler: { dataReadFromSocket, socketError in
                if socketError == nil, let dataToWriteToFlow = dataReadFromSocket, !dataToWriteToFlow.isEmpty {
                    tcpFlow.write(dataToWriteToFlow) { flowError in
                        if flowError == nil {
                            // no op, if write executed correctly
                        } else {
                            os_log("error during flow write! %s", flowError.debugDescription)
                            socket.closeConnection()
                            self.closeFlow(tcpFlow)
                        }
                    }
                } else { // handling socket readData() errors or read 0 data from socket
                    if socketError == nil {
                        os_log("read no data from socket readData()") // is this error different from the other one? (verify this!)
                    } else {
                        os_log("error during connection read! %s", socketError.debugDescription)
                    }
                    socket.closeConnection()
                    self.closeFlow(tcpFlow)
                }
            })
        }
    }
}
