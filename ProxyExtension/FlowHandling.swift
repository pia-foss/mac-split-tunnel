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
            if let tcpFlow = flow as? NEAppProxyTCPFlow {
                os_log("managing %s TCP flow", appID)
                Task.detached(priority: .background) {
                    self.manageTCPFlow(tcpFlow, appID)
                }
                return true
            } else {
                os_log("error: UDP flow caught by handleNewFlow()")
            }
        }
        return false
    }
    
    private func manageTCPFlow(_ flow: NEAppProxyTCPFlow, _ appID: String) {
        // open() is used by an NEProvider implementation
        // to indicate to the system that the caller is ready
        // to start reading and writing to this flow.
        flow.open(withLocalEndpoint: nil) { error in
            if (error != nil) {
                os_log("error during flow open! %s", error.debugDescription)
                return
            }

            let (endpointAddress, endpointPort) = getAddressAndPort(endpoint: flow.remoteEndpoint as! NWHostEndpoint)
            
            // Create the socket that will proxy the traffic
            let socket = Socket(transportProtocol: TransportProtocol.TCP,
                                             host: endpointAddress!,
                                             port: endpointPort!,
                                          appName: appID)
            var result = true
            if !socket.create() {
                os_log("Error creating TCP socket of app: %s", appID)
                result = false
            }
            if !socket.bindToNetworkInterface(interfaceName: self.networkInterface!) {
                os_log("Error binding TCP socket of app: %s", appID)
                result = false
            }
            if !socket.connectToHost() {
                os_log("Error connecting TCP socket of app: %s", appID)
                result = false
            }
            
            if !result {
                socket.close()
                closeFlow(flow)
                return
            }
            
            // These two functions are async using escaping completion handler
            // They are also recursive: if they complete successfully they call
            // themselves again.
            // Whenever any error is detected in both these functions, the flow is
            // closed as suggested by mother Apple (the application will likely deal
            // with the dropped connection).
            // Both functions are non-blocking
            TCPIO.readOutboundTraffic(flow, socket)
            TCPIO.readInboundTraffic(flow, socket)
        }
    }
    
    // MARK: Managing UDP flows
    // handleNewUDPFlow() is called whenever an application
    // creates a new UDP socket.
    override func handleNewUDPFlow(_ flow: NEAppProxyUDPFlow, initialRemoteEndpoint remoteEndpoint: NWEndpoint) -> Bool {
        let appID = flow.metaData.sourceAppSigningIdentifier
        
        if appsToManage!.contains(appID) {
            os_log("managing %s UDP flow", appID)
            Task.detached(priority: .background) {
                self.manageUDPFlow(flow, appID)
            }
            return true
        }
        return false
    }
    
    private func manageUDPFlow(_ flow: NEAppProxyUDPFlow, _ appID: String) {
        flow.open(withLocalEndpoint: nil) { error in
            if (error != nil) {
                os_log("error during flow open! %s", error.debugDescription)
            }
            
            let socket = Socket(transportProtocol: TransportProtocol.UDP,
                                          appName: appID)
            var result = true
            if !socket.create() {
                os_log("Error creating UDP socket of app: %s", appID)
                result = false
            }
            if !socket.bindToNetworkInterface(interfaceName: self.networkInterface!) {
                os_log("Error binding UDP socket of app: %s", appID)
                result = false
            }
            // Not calling connect() on a UDP socket.
            // Doing that will turn the socket into a "connected datagram socket".
            // That will prevent the application from receiving and sending data 
            // to different endpoints
            
            if !result {
                socket.close()
                closeFlow(flow)
                return
            }
            
            // UDPIO.readOutboundTraffic(flow, socket)
            // UDPIO.readInboundTraffic(flow, socket)
        }
    }
}
