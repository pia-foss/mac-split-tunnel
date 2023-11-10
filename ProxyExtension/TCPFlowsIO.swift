import Foundation
import NetworkExtension
import os.log

@available(macOS 11.0, *)
extension STProxyProvider {
    func readTCPFlowData(_ tcpFlow: NEAppProxyTCPFlow, _ socket: Socket) {
        // Reading the application OUTBOUND traffic
        tcpFlow.readData { dataReadFromFlow, flowError in
            if flowError == nil, let dataToWriteToSocket = dataReadFromFlow, !dataToWriteToSocket.isEmpty {
                if socket.status == .closed {
                    self.closeFlow(tcpFlow)
                    return
                }
                // Writing the application OUTBOUND traffic
                socket.writeData(dataToWriteToSocket, completionHandler: { socketError in
                    if socketError == nil {
                        // read executed correctly, calling it again
                        self.readTCPFlowData(tcpFlow, socket)
                    } else { 
                        // handling errors for socket send()
                        os_log("error during socket writeData()! %s", socketError.debugDescription)
                        socket.closeConnection()
                        self.closeFlow(tcpFlow)
                    }
                })
            } else { 
                // handling errors for flow readData()
                // If data has a length of 0 then no data can be
                // subsequently read from the flow.
                if flowError != nil {
                    os_log("error during flow read! %s", flowError.debugDescription)
                } else {
                    os_log("read no data from flow readData()")
                }
                // whichever error we get, we close both the
                // connection and the flow
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
        // socket.readData() needs to be called in a detached task
        // because it contains a blocking function: recv().
        Task.detached(priority: .background) {
            // Reading the application INBOUND traffic
            socket.readData(completionHandler: { dataReadFromSocket, socketError in
                if socketError == nil, let dataToWriteToFlow = dataReadFromSocket, !dataToWriteToFlow.isEmpty {
                    // Writing the application INBOUND traffic
                    tcpFlow.write(dataToWriteToFlow) { flowError in
                        if flowError == nil {
                            // write executed correctly, calling it again
                            self.writeTCPFlowData(tcpFlow, socket)
                        } else {
                            // handling errors for flow write()
                            os_log("error during flow write! %s", flowError.debugDescription)
                            socket.closeConnection()
                            self.closeFlow(tcpFlow)
                        }
                    }
                } else { 
                    // handling errors for socket recv()
                    if socketError != nil {
                        os_log("error during socket readData()! %s", socketError.debugDescription)
                    } else {
                        os_log("read no data from socket readData()")
                    }
                    socket.closeConnection()
                    self.closeFlow(tcpFlow)
                }
            })
        }
    }
}
