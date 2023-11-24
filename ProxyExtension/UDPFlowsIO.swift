import Foundation
import NetworkExtension
import os.log

class UDPIO {
    static func readOutboundTraffic(_ flow: NEAppProxyUDPFlow, _ socket: Socket) {
        // Reading the application OUTBOUND UDP traffic
        //
        // This is fundamentally different compared to a TCP flow.
        // readDatagrams() can read multiple datagrams coming from multiple endpoints.
        flow.readDatagrams { _dataArray, _endpointArray, flowError in
            if flowError == nil, let dataArray = _dataArray, !dataArray.isEmpty, let endpointArray = _endpointArray, !endpointArray.isEmpty {
                Logger.log.debug("\(socket.appID) wants to write \(dataArray.count) UDP streams")
                writeOutboundTraffic(flow, socket, dataArray, endpointArray)
            } else {
                handleError(flowError, "UDP flow readDatagrams()", flow, socket)
            }
        }
    }

    private static func writeOutboundTraffic(_ flow: NEAppProxyUDPFlow, _ socket: Socket, _ dataArray: [Data], _ endpointArray: [NWEndpoint]) {
        if socket.status == .closed {
            handleError(SocketError.socketClosed, "before UDP socket writeDataUDP()", flow, socket)
            return
        }
        socket.writeDataUDP(dataArray, endpointArray, completionHandler: { socketError in
            if socketError == nil {
                Logger.log.debug("\(socket.appID) have written \(dataArray.count) UDP streams successfully")
                // read outbound completed successfully, calling it again
                readOutboundTraffic(flow, socket)
            } else { 
                handleError(socketError, "UDP socket writeDataUDP()", flow, socket)
            }
        })
    }
    
    static func readInboundTraffic(_ flow: NEAppProxyUDPFlow, _ socket: Socket) {
        // socket.readData() needs to be called in a detached task
        // because it contains a blocking function: recvfrom().
        Task.detached(priority: .background) {
            if socket.status == .closed {
                handleError(SocketError.socketClosed, "before UDP socket readDataUDP()", flow, socket)
                return
            }
            // Reading the application INBOUND UDP traffic
            socket.readDataUDP(completionHandler: { _data, _endpoint, socketError in
                if socketError == nil, let data = _data, !data.isEmpty, let endpoint = _endpoint {
                    Logger.log.debug("\(socket.appID) is waiting to read UDP \(data)")
                    writeInboundTraffic(flow, socket, data, endpoint)
                } else {
                    handleError(socketError, "UDP socket readDataUDP()", flow, socket)
                }
            })
        }
    }

    private static func writeInboundTraffic(_ flow: NEAppProxyUDPFlow, _ socket: Socket, _ data: Data, _ endpoint: NWEndpoint) {
        flow.writeDatagrams([data], sentBy: [endpoint]) { flowError in
            if flowError == nil {
                Logger.log.debug("\(socket.appID) has read UDP \(data)")
                // read inbound completed successfully, calling it again
                readInboundTraffic(flow, socket)
            } else {
                handleError(flowError, "UDP flow writeDatagrams()", flow, socket)
            }
        }
    }
}
