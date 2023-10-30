import Foundation
import NetworkExtension
import os.log

@available(macOS 11.0, *)
extension STProxyProvider {
    
    // handleNewFlow() is called whenever an application
    // creates a new TCP socket.
    //
    //   return true  ->
    //     The flow of this app will be managed by the network extension
    //   return false ->
    //     The flow of this app will NOT be managed.
    //     It will be routed using the system's routing tables
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        let appID = flow.metaData.sourceAppSigningIdentifier
                
        // A condition could be added here to achieve inverse split tunnelling.
        // Given the list of apps, we could either:
        // - manage the flows of ONLY the apps in the list
        // - manage the flows of ALL the OTHER apps, EXCEPT the ones in the list.
        if appsToManage!.contains(appID) {
            // flow.open() must be called before returning true in handleNewFlow
            if let tcpFlow = flow as? NEAppProxyTCPFlow {
                os_log("managing %s TCP flow", appID)
                manageTCPFlow(tcpFlow)
                return true
            } else {
                os_log("error: UDP flow caught by handleNewFlow()")
            }
        }
        return false
    }
    
    // handleNewUDPFlow() is called whenever an application
    // creates a new UDP socket.
    //
    // By overriding this method, all UDP flows will be
    // caught by this function instead of handleNewFlow()
    override func handleNewUDPFlow(_ flow: NEAppProxyUDPFlow, initialRemoteEndpoint remoteEndpoint: NWEndpoint) -> Bool {
        let appID = flow.metaData.sourceAppSigningIdentifier
        
        if appsToManage!.contains(appID) {
            os_log("managing %s UDP flow", appID)
            manageUDPFlow(flow, remoteEndpoint)
            return true
        }
        return false
    }
    
    // MARK: Managing TCP flows
    private func manageTCPFlow(_ tcpFlow: NEAppProxyTCPFlow) {
        // open() is used by an NEProvider implementation
        // to indicate to the system that the caller is ready
        // to start reading and writing to this flow.
        tcpFlow.open(withLocalEndpoint: nil) { error in
            // this is an escaping closure, therefore it is async
            // and can outlive the manageTCPFlow function
            if (error != nil) {
                os_log("error during flow open! %s", error.debugDescription)
            }
            
            // read-only info about the flow
            let appName = tcpFlow.metaData.sourceAppSigningIdentifier
            let remoteEndpoint = tcpFlow.remoteEndpoint.description
            let parts = remoteEndpoint.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else {
                return
            }
            let remoteEndpointAddress = String(parts[0])
            let remoteEndpointPort = UInt16(parts[1])!
            
            // Create the socket that will proxy the traffic
            let socket = Socket(transportProtocol: TransportProtocol.TCP,
                                             host: remoteEndpointAddress,
                                             port: remoteEndpointPort,
                                          appName: appName)
            socket.create()
            socket.bindToNetworkInterface(interfaceName: "en0")
            socket.connectToHost()
            
            // We read from the flow:
            // that means reading the OUTBOUND traffic of the application
            // TODO: Possible rework, change this from a recursive function to a while (true) loop
            self.readTCPFlowData(tcpFlow, socket)
        }
    }
    
    private func closeFlow(_ tcpFlow: NEAppProxyTCPFlow) {
        // close the flow when you dont want to read and write to it anymore
        tcpFlow.closeReadWithError(nil)
        tcpFlow.closeWriteWithError(nil)
    }
    
    private func readTCPFlowData(_ tcpFlow: NEAppProxyTCPFlow, _ socket: Socket) {
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
    
    private func writeTCPFlowData(_ tcpFlow: NEAppProxyTCPFlow, _ socket: Socket) {
        if socket.status == .closed {
            self.closeFlow(tcpFlow)
            return
        }
        // This call is blocking: until some data is read the closure will not be called
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
    
    // MARK: Managing UDP flows
    // TODO: This function is missing implementation
    private func manageUDPFlow(_ udpFlow: NEAppProxyUDPFlow, _ endpoint: NWEndpoint) {
        udpFlow.open(withLocalEndpoint: udpFlow.localEndpoint as? NWHostEndpoint) { error in
            if let error = error {
                os_log("Failed to open udpFlow: \(error)")
                // close flow here
                return
            }
        // continue by calling open() on udpFlow
        }
    }
}
