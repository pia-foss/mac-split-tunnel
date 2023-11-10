import Foundation
import NetworkExtension
import os.log

@available(macOS 11.0, *)
extension STProxyProvider {
    func readUDPFlowData(_ udpFlow: NEAppProxyUDPFlow, _ socket: Socket) {
        // Reading the application OUTBOUND traffic
        // This call is blocking: until some data is read the closure will not be called
        //
        // This is fundamentally different compared to TCP flows.
        // readDatagrams() can read multiple datagrams coming from multiple endpoints.
        // For now, this implementation only supports one UDP socket
        udpFlow.readDatagrams { dataArrayReadFromFlow, endpointArray, flowError in
            if flowError == nil, let dataToWriteToSocket = dataArrayReadFromFlow, !dataToWriteToSocket.isEmpty, let destinationEndpoints = endpointArray, !destinationEndpoints.isEmpty {
                // Writing to the real endpoint (via the local socket) the application OUTBOUND traffic
                if socket.status == .closed {
                    self.closeFlow(udpFlow)
                    return
                }
                socket.writeDataUDP(dataToWriteToSocket, destinationEndpoints, completionHandler: { socketError in
                    if socketError == nil {
                        // wait for an answer from the endpoint
                        self.writeUDPFlowData(udpFlow, socket)
                        self.readUDPFlowData(udpFlow, socket)
                    } else { // handling errors for socket send()
                        os_log("error during socket writeData! %s", socketError.debugDescription)
                        socket.closeConnection()
                        self.closeFlow(udpFlow)
                    }
                })
            } else { // handling errors for flow readDatagrams()
                if flowError != nil {
                    os_log("error during flow read! %s", flowError.debugDescription)
                } else {
                    // if error is nil and read data is nil
                    // it means no data can no longer be read and wrote to the flow
                    os_log("read no data from flow readDatagrams()")
                }
                // no op: We stop calling readTCPFlowData(), ending the recursive loop
                socket.closeConnection()
                self.closeFlow(udpFlow)
            }
        }
    }
    
    func writeUDPFlowData(_ udpFlow: NEAppProxyUDPFlow, _ socket: Socket) {
        if socket.status == .closed {
            self.closeFlow(udpFlow)
            return
        }
        // This call is blocking: until some data is read the closure will not be called
        socket.readDataUDP(completionHandler: { dataReadFromSocket, endpoint, socketError in
            if socketError == nil, let dataToWriteToFlow = dataReadFromSocket, !dataToWriteToFlow.isEmpty, let destinationEndpoint = endpoint {
                udpFlow.writeDatagrams([dataToWriteToFlow], sentBy: [destinationEndpoint]) { flowError in
                    if flowError == nil {
                        // no op, write executed correctly
                    } else {
                        os_log("error during UDP flow write! %s", flowError.debugDescription)
                        socket.closeConnection()
                        self.closeFlow(udpFlow)
                    }
                }
            } else { // handling socket readData() errors or read 0 data from socket
                if socketError == nil {
                    os_log("read no data from socket readDataUDP()")
                } else {
                    os_log("error during udp stream read! %s", socketError.debugDescription)
                }
                socket.closeConnection()
                self.closeFlow(udpFlow)
            }
        })
    }
}
