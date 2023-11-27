import Foundation
import NetworkExtension
import os.log

class UDPIO {
    static func handleRead(_ flow: NEAppProxyUDPFlow, _ socket: Socket) {
        // Reading the application OUTBOUND UDP traffic
        //
        // This is fundamentally different compared to a TCP flow.
        // readDatagrams() can read multiple datagrams coming from multiple endpoints.
        flow.readDatagrams { _dataArray, _endpointArray, flowError in
            if flowError == nil, let dataArray = _dataArray, !dataArray.isEmpty, let endpointArray = _endpointArray, !endpointArray.isEmpty {
                Logger.log.debug("\(socket.appID) wants to write \(dataArray.count) UDP streams")
                writeToSocket(flow, socket, dataArray, endpointArray)
                handleRead(flow, socket)
            } else {
                handleError(flowError, "UDP flow readDatagrams()", flow, socket)
            }
        }
    }

    private static func writeToSocket(_ flow: NEAppProxyUDPFlow, _ socket: Socket, _ dataArray: [Data], _ endpointArray: [NWEndpoint]) {
        if socket.status == .closed {
            handleError(SocketError.socketClosed, "before UDP socket writeDataUDP()", flow, socket)
            return
        }
        socket.writeDataUDP(dataArray, endpointArray, completionHandler: { socketError in
            if socketError == nil {
                Logger.log.debug("\(socket.appID) have written \(dataArray.count) UDP streams successfully")
                // no op
            } else { 
                handleError(socketError, "UDP socket writeDataUDP()", flow, socket)
            }
        })
    }
    
    static func handleWrite(_ flow: NEAppProxyUDPFlow, _ socket: Socket) {
        if socket.status == .closed {
            handleError(SocketError.socketClosed, "before UDP socket readDataUDP()", flow, socket)
            return
        }
        // Reading the application INBOUND UDP traffic
        socket.readDataUDP(completionHandler: { _data, _endpoint, socketError in
            if socketError == nil, let data = _data, !data.isEmpty, let endpoint = _endpoint {
                Logger.log.debug("\(socket.appID) is waiting to read UDP \(data)")
                writeToFlow(flow, socket, data, endpoint)
                handleWrite(flow, socket)
            } else {
                handleError(socketError, "UDP socket readDataUDP()", flow, socket)
            }
        })
    }

    private static func writeToFlow(_ flow: NEAppProxyUDPFlow, _ socket: Socket, _ data: Data, _ endpoint: NWEndpoint) {
        flow.writeDatagrams([data], sentBy: [endpoint]) { flowError in
            if flowError == nil {
                Logger.log.debug("\(socket.appID) has read UDP \(data)")
                // no op
            } else {
                handleError(flowError, "UDP flow writeDatagrams()", flow, socket)
            }
        }
    }
}
