import Foundation
import NetworkExtension
import os.log

class TCPIO {
    static func readOutboundTraffic(_ flow: NEAppProxyTCPFlow, _ socket: Socket) {
        // Reading the application OUTBOUND TCP traffic
        flow.readData { dataReadFromFlow, flowError in
            if flowError == nil, let data = dataReadFromFlow, !data.isEmpty {
                Logger.log.debug("\(socket.appID) wants to write TCP \(data)")
                writeOutboundTraffic(flow, socket, data)
            } else {
                handleError(flowError, "TCP flow readData()", flow, socket)
            }
        }
    }

    private static func writeOutboundTraffic(_ flow: NEAppProxyTCPFlow, _ socket: Socket, _ data: Data) {
        if socket.status == .closed {
            handleError(SocketError.socketClosed, "before TCP socket writeData()", flow, socket)
            return
        }
        socket.writeData(data, completionHandler: { socketError in
            if socketError == nil {
                Logger.log.debug("\(socket.appID) have written TCP \(data) successfully")
                // read outbound completed successfully, calling it again
                readOutboundTraffic(flow, socket)
            } else { 
                handleError(socketError, "TCP socket writeData()", flow, socket)
            }
        })
    }
    
    static func readInboundTraffic(_ flow: NEAppProxyTCPFlow, _ socket: Socket) {
        // socket.readData() needs to be called in a detached task
        // because it contains a blocking function: recv().
        Task.detached(priority: .background) {
            if socket.status == .closed {
                handleError(SocketError.socketClosed, "before TCP socket readData()", flow, socket)
                return
            }
            // Reading the application INBOUND TCP traffic
            socket.readData(completionHandler: { dataReadFromSocket, socketError in
                if socketError == nil, let data = dataReadFromSocket, !data.isEmpty {
                    Logger.log.debug("\(socket.appID) is waiting to read TCP \(data)")
                    writeInboundTraffic(flow, socket, data)
                } else {
                    handleError(socketError, "TCP socket readData()", flow, socket)
                }
            })
        }
    }

    private static func writeInboundTraffic(_ flow: NEAppProxyTCPFlow, _ socket: Socket, _ data: Data) {
        flow.write(data) { flowError in
            if flowError == nil {
                Logger.log.debug("\(socket.appID) has read TCP \(data)")
                // read inbound completed successfully, calling it again
                readInboundTraffic(flow, socket)
            } else {
                handleError(flowError, "TCP flow write()", flow, socket)
            }
        }
    }
}
