import Foundation
import NetworkExtension
import os.log

class UDPIO {
    static func readOutboundTraffic(_ flow: NEAppProxyUDPFlow, _ socket: Socket) {
        // Reading the application OUTBOUND traffic
        //
        // This is fundamentally different compared to a TCP flow.
        // readDatagrams() can read multiple datagrams coming from multiple endpoints.
        flow.readDatagrams { _dataArray, _endpointArray, flowError in
            if flowError == nil, let dataArray = _dataArray, !dataArray.isEmpty, let endpointArray = _endpointArray, !endpointArray.isEmpty {
                writeOutboundTraffic(flow, socket, dataArray, endpointArray)
            } else {
                handleError(flowError, "flow readDatagrams()", flow, socket)
            }
        }
    }

    private static func writeOutboundTraffic(_ flow: NEAppProxyUDPFlow, _ socket: Socket, _ dataArray: [Data], _ endpointArray: [NWEndpoint]) {
        if socket.status == .closed {
            Logger.log.error("error: local UDP socket is closed, aborting read")
            closeFlow(flow)
            return
        }
        socket.writeDataUDP(dataArray, endpointArray, completionHandler: { socketError in
            if socketError == nil {
                // read outbound completed successfully, calling it again
                readOutboundTraffic(flow, socket)
            } else { 
                handleError(socketError, "socket writeDataUDP()", flow, socket)
            }
        })
    }
    
    static func readInboundTraffic(_ flow: NEAppProxyUDPFlow, _ socket: Socket) {
        // socket.readData() needs to be called in a detached task
        // because it contains a blocking function: recvfrom().
        Task.detached(priority: .background) {
            if socket.status == .closed {
                Logger.log.error("error: local UDP socket is closed, aborting read")
                closeFlow(flow)
                return
            }
            // Reading the application INBOUND traffic
            socket.readDataUDP(completionHandler: { _data, _endpoint, socketError in
                if socketError == nil, let data = _data, !data.isEmpty, let endpoint = _endpoint {
                    writeInboundTraffic(flow, socket, data, endpoint)
                } else {
                    handleError(socketError, "socket readDataUDP()", flow, socket)
                }
            })
        }
    }

    private static func writeInboundTraffic(_ flow: NEAppProxyUDPFlow, _ socket: Socket, _ data: Data, _ endpoint: NWEndpoint) {
        flow.writeDatagrams([data], sentBy: [endpoint]) { flowError in
            if flowError == nil {
                // read inbound completed successfully, calling it again
                readInboundTraffic(flow, socket)
            } else {
                handleError(flowError, "flow writeDatagrams()", flow, socket)
            }
        }
    }
}
