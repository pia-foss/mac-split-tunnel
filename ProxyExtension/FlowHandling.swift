import Foundation
import NetworkExtension
import os.log

@available(macOS 11.0, *)
extension STProxyProvider {
    // MARK: Managing TCP flows
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
                Task.detached(priority: .background) {
                    self.manageTCPFlow(tcpFlow)
                }
                return true
            } else {
                os_log("error: UDP flow caught by handleNewFlow()")
            }
        }
        return false
    }
    
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
            let (endpointAddress, endpointPort) = getAddressAndPort(endpoint: tcpFlow.remoteEndpoint)
            
            // Create the socket that will proxy the traffic
            let socket = Socket(transportProtocol: TransportProtocol.TCP,
                                host: endpointAddress!,
                                port: endpointPort!,
                                          appName: appName)
            socket.create()
            socket.bindToNetworkInterface(interfaceName: self.networkInterface!)
            socket.connectToHost()
            
            // We read from the flow:
            // that means reading the OUTBOUND traffic of the application
            self.readTCPFlowData(tcpFlow, socket)
        }
    }
    
    // MARK: Managing UDP flows
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
    
    private func manageUDPFlow(_ udpFlow: NEAppProxyUDPFlow, _ endpoint: NWEndpoint) {
        udpFlow.open(withLocalEndpoint: nil) { error in
            if (error != nil) {
                os_log("error during flow open! %s", error.debugDescription)
            }
            
            let appName = udpFlow.metaData.sourceAppSigningIdentifier
            
            let socket = Socket(transportProtocol: TransportProtocol.UDP,
                                          appName: appName)
            socket.create()
            socket.bindToNetworkInterface(interfaceName: self.networkInterface!)
            // Not calling connect() on a UDP socket since the application might
            // want to receive and send data to different endpoints
            
            self.readUDPFlowData(udpFlow, socket)
        }
    }
    
    func closeFlow(_ flow: NEAppProxyFlow) {
        // close the flow when you dont want to read and write to it anymore
        flow.closeReadWithError(nil)
        flow.closeWriteWithError(nil)
    }
}
