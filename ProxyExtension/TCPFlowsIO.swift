import Foundation
import NetworkExtension
import os.log

@available(macOS 11.0, *)
class TCPIO {
    static func readOutboundTraffic(_ flow: NEAppProxyTCPFlow, _ socket: Socket) {
        // Reading the application OUTBOUND traffic
        flow.readData { dataReadFromFlow, flowError in
            if flowError == nil, let data = dataReadFromFlow, !data.isEmpty {
                writeOutboundTraffic(flow, socket, data)
            } else {
                handleError(flowError, "flow readData()", flow, socket)
            }
        }
    }

    private static func writeOutboundTraffic(_ flow: NEAppProxyTCPFlow, _ socket: Socket, _ data: Data) {
        if socket.status == .closed {
            os_log("error: local socket is closed, aborting read")
            closeFlow(flow)
            return
        }
        socket.writeData(data, completionHandler: { socketError in
            if socketError == nil {
                // read outbound completed successfully, calling it again
                readOutboundTraffic(flow, socket)
            } else { 
                handleError(socketError, "socket writeData()", flow, socket)
            }
        })
    }
    
    static func readInboundTraffic(_ flow: NEAppProxyTCPFlow, _ socket: Socket) {
        // socket.readData() needs to be called in a detached task
        // because it contains a blocking function: recv().
        Task.detached(priority: .background) {
            if socket.status == .closed {
                os_log("error: local socket is closed, aborting read")
                closeFlow(flow)
                return
            }
            // Reading the application INBOUND traffic
            socket.readData(completionHandler: { dataReadFromSocket, socketError in
                if socketError == nil, let data = dataReadFromSocket, !data.isEmpty {
                    writeInboundTraffic(flow, socket, data)
                } else {
                    handleError(socketError, "socket readData()", flow, socket)
                }
            })
        }
    }

    private static func writeInboundTraffic(_ flow: NEAppProxyTCPFlow, _ socket: Socket, _ data: Data) {
        flow.write(data) { flowError in
            if flowError == nil {
                // read inbound completed successfully, calling it again
                readInboundTraffic(flow, socket)
            } else {
                handleError(flowError, "flow write()", flow, socket)
            }
        }
    }
}
