import Foundation
import NetworkExtension
import os.log

class TCPIO {
    static func handleRead(_ flow: NEAppProxyTCPFlow, _ socket: Socket) {
        // Reading the application OUTBOUND TCP traffic
        flow.readData { dataReadFromFlow, flowError in
            if flowError == nil, let data = dataReadFromFlow, !data.isEmpty {
                Logger.log.debug("\(socket.appID) wants to write TCP \(data)")
                writeToSocket(flow, socket, data)
                handleRead(flow, socket)
            } else {
                handleError(flowError, "TCP flow readData()", flow, socket)
            }
        }
    }

    private static func writeToSocket(_ flow: NEAppProxyTCPFlow, _ socket: Socket, _ data: Data) {
        if socket.status == .closed {
            handleError(SocketError.socketClosed, "before TCP socket writeData()", flow, socket)
            return
        }
        socket.writeData(data, completionHandler: { socketError in
            if socketError == nil {
                Logger.log.debug("\(socket.appID) have written TCP \(data) successfully")
                // no op
            } else { 
                handleError(socketError, "TCP socket writeData()", flow, socket)
            }
        })
    }
    
    static func handleWrite(_ flow: NEAppProxyTCPFlow, _ socket: Socket) {
        if socket.status == .closed {
            handleError(SocketError.socketClosed, "before TCP socket readData()", flow, socket)
            return
        }
        // Reading the application INBOUND TCP traffic
        socket.readData(completionHandler: { dataReadFromSocket, socketError in
            if socketError == nil, let data = dataReadFromSocket, !data.isEmpty {
                Logger.log.debug("\(socket.appID) is waiting to read TCP \(data)")
                writeToFlow(flow, socket, data)
                handleWrite(flow, socket)
            } else {
                handleError(socketError, "TCP socket readData()", flow, socket)
            }
        })
    }

    private static func writeToFlow(_ flow: NEAppProxyTCPFlow, _ socket: Socket, _ data: Data) {
        flow.write(data) { flowError in
            if flowError == nil {
                Logger.log.debug("\(socket.appID) has read TCP \(data)")
                // no op
            } else {
                handleError(flowError, "TCP flow write()", flow, socket)
            }
        }
    }
}
