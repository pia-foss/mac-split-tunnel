import Foundation
import NetworkExtension
import os.log

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
                Logger.log.info("managing \(appID) TCP flow")
                Task.detached(priority: .background) {
                    self.manageTCPFlow(tcpFlow, appID)
                }
                return true
            } else {
                Logger.log.info("error: UDP flow caught by handleNewFlow()")
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
                Logger.log.info("error during flow open! \(error.debugDescription)")
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
                Logger.log.debug("Error creating TCP socket of app: \(appID)")
                result = false
            }
            if !socket.bindToNetworkInterface(interfaceName: self.networkInterface!) {
                Logger.log.debug("Error binding TCP socket of app: \(appID)")
                result = false
            }
            if !socket.connectToHost() {
                Logger.log.debug("Error connecting TCP socket of app: \(appID)")
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
            Logger.log.info("managing \(appID) UDP flow")
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
                Logger.log.info("error during flow open! \(error.debugDescription)")
            }
            
            let socket = Socket(transportProtocol: TransportProtocol.UDP,
                                          appName: appID)
            var result = true
            if !socket.create() {
                Logger.log.error("Error creating UDP socket of app: \(appID)")
                result = false
            }
            if !socket.bindToNetworkInterface(interfaceName: self.networkInterface!) {
                Logger.log.error("Error binding UDP socket of app: \(appID)")
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
            
             UDPIO.readOutboundTraffic(flow, socket)
             UDPIO.readInboundTraffic(flow, socket)
        }
    }
}
