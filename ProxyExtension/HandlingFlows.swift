import Foundation
import NetworkExtension
import os.log

@available(macOS 11.0, *)
extension STProxyProvider {
    
    // handleNewFlow is called whenever an application
    // creates a new TCP/UDP socket.
    //
    //   return true  -> to handle a new flow
    //     The flow of this app will be managed by the network extension
    //   return false -> (NETransparentProxyProvider)
    //     The flow of this app will NOT be managed.
    //     It will be routed using the system's routing tables
    //   return false -> (NEAppProxyProvider or NEDNSProxyProvider)
    //     The flow is discarded and the connection is closed
    //
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        let appID = flow.metaData.sourceAppSigningIdentifier
        os_log("deciding if we need to handle %s flow", appID)
                
        // A condition could be added here to achieve inverse split tunnelling.
        // Given the list of apps, we could either:
        // - manage the flows of ONLY the apps in the list
        // - manage the flows of ALL the OTHER apps, EXCEPT the ones in the list.
        //
        if appsToManage!.contains(appID) {
            // flow.open() must be called before returning true in handleNewFlow
            manageFlow(flow)
            return true
        }
        return false
    }
    
    private func manageFlow(_ flow: NEAppProxyFlow) {
        if let TCPFlow = flow as? NEAppProxyTCPFlow {
            manageTCPFlow(TCPFlow)
        }
        else if let UDPFlow = flow as? NEAppProxyUDPFlow {
            manageUDPFlow(UDPFlow)
        }
    }
    
    // MARK: Managing TCP flows
    private func manageTCPFlow(_ TCPFlow: NEAppProxyTCPFlow) {
        // open() is used by an NEProvider implementation
        // to indicate to the system that the caller is ready
        // to start reading and writing to this flow.
        //
        // LocalEndpoint: The address and port that should be used as the
        // local endpoint of the socket associated with this flow.
        // If the source application already specifed a local endpoint
        // by binding the socket then this parameter is ignored
        TCPFlow.open(withLocalEndpoint: nil) { error in
            // this is an escaping closure, therefore it is async
            // and can outlive the manageTCPFlow function
            if (error != nil) {
                os_log("error during flow open! %s", error.debugDescription)
            }
            
            // read-only info about the flow
            let appName = TCPFlow.metaData.sourceAppSigningIdentifier
            let remoteEndpoint = TCPFlow.remoteEndpoint.description
            let parts = remoteEndpoint.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else {
                return
            }
            let remoteEndpointAddress = String(parts[0])
            let remoteEndpointPort = UInt16(parts[1])!
            
            // Create the socket that will proxy the traffic
            let socket = TCPSocket(host: remoteEndpointAddress, port: remoteEndpointPort)
            socket.create()
            socket.connectToHost()
            
            // We read from the flow:
            // that means reading the OUTBOUND traffic of the application
            self.readTCPFlowData(TCPFlow, socket)
        }
        
        // close the flow when you dont want to read and write to it anymore
        // TODO: is that needed to restore "normal" traffic for the applications that we stop managing?
        // Yes, probably when we disable split tunnelling.
        // Does the app work properly, or does it have to be restarted?
        // TCPFlow.closeReadWithError(nil)
        // TCPFlow.closeWriteWithError(nil)
    }
    
    private func readTCPFlowData(_ TCPFlow: NEAppProxyTCPFlow, _ socket: TCPSocket) {
        // If data has a length of 0 then no data can be subsequently read from the flow.
        // The completion handler is only called for the single read operation that was
        // initiated by calling this method.
        //
        // If the caller wants to read more data then it should call this method again
        // to schedule another read operation and another execution of the
        // completion handler block.
        // This call is blocking: until some data is read the closure will not be called
        TCPFlow.readData { data, error in
            if error == nil, let readData = data, !readData.isEmpty {
                // writing to the real endpoint (via socket) what we read from the flow.
                // This is the application OUTBOUND traffic
                socket.writeData(readData, completionHandler: { writeError in
                    if writeError == nil {
                        // wait for answer from the endpoint
                        self.writeTCPFlowData(TCPFlow, socket)
                        self.readTCPFlowData(TCPFlow, socket)
                    } else {
                        os_log("error during socket writeData! %s", writeError.debugDescription)
                    }
                })
            } else {
                // Handle an error on the flow read.
                if error != nil {
                    os_log("error during flow read! %s", error.debugDescription)
                } else {
                    // TCPFlow.readData returned 0 data, so no data can be read from the flow.
                    // We try calling TCPFlow.readData anyway
                    //self.readTCPFlowData(TCPFlow, socket)
                }
            }
        }
    }
    
    private func writeTCPFlowData(_ TCPFlow: NEAppProxyTCPFlow, _ socket: TCPSocket) {
        // This call is blocking: until some data is read the closure will not be called
        socket.readData(completionHandler: { data, error in
            if error == nil, let writeData = data, !writeData.isEmpty {
                TCPFlow.write(writeData) { flowError in
                    if flowError == nil {
                        //self.readTCPFlowData(TCPFlow, socket)
                        os_log("no op")
                    } else {
                        os_log("error during flow write! %s", flowError.debugDescription)
                    }
                }
            } else {
                // Handle an error on the connection read.
                if error != nil {
                    os_log("error during connection read! %s", error.debugDescription)
                } else {
                    os_log("read no data from socket read!")
                }
            }
        })
    }
    
    // MARK: Managing UDP flows
    // TODO: This function is missing implementation
    private func manageUDPFlow(_ UDPFlow: NEAppProxyUDPFlow) {
        UDPFlow.open(withLocalEndpoint: UDPFlow.localEndpoint as? NWHostEndpoint) { error in
            if let error = error {
                os_log("Failed to open UDP flow: \(error)")
                // close flow here
                return
            }

            os_log("Opened UDP flow successfuly")
            // read from flow
        }
    }
}
