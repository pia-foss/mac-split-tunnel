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
                Logger.log.info("\(appID) Managing a new TCP flow")
                Task.detached(priority: .medium) {
                    self.manageTCPFlow(tcpFlow, appID)
                }
                return true
            } else {
                Logger.log.error("Error: \(appID)'s UDP flow caught by handleNewFlow()")
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
                Logger.log.error("Error: \(appID) \"\(error!.localizedDescription)\" in TCP flow open()")
                return
            }

            let (endpointAddress, endpointPort) = getAddressAndPort(endpoint: flow.remoteEndpoint as! NWHostEndpoint)
            
            // Create the socket that will proxy the traffic
            let socket = Socket(transportProtocol: TransportProtocol.TCP,
                                             host: endpointAddress!,
                                             port: endpointPort!,
                                          appID: appID)
            var result = true
            if !socket.create() {
                Logger.log.error("Error: Failed to create \(appID)'s TCP socket")
                result = false
            }
            if !socket.bindToNetworkInterface(interfaceName: self.networkInterface!) {
                Logger.log.error("Error: Failed to bind \(appID)'s TCP socket")
                result = false
            }
            if !socket.connectToHost() {
                Logger.log.error("Error: Failed to connect \(appID)'s TCP socket")
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
            Task.detached(priority: .high) {
                let semaphore = DispatchSemaphore(value: 0)
                while (socket.status != .closed) {
                    TCPIO.handleRead(flow, socket, semaphore)
                    semaphore.wait()
                }
            }
            Task.detached(priority: .high) {
                let semaphore = DispatchSemaphore(value: 0)
                while (socket.status != .closed) {
                    TCPIO.handleWrite(flow, socket, semaphore)
                    semaphore.wait()
                }
            }
        }
    }
    
    // MARK: Managing UDP flows
    // handleNewUDPFlow() is called whenever an application
    // creates a new UDP socket.
    override func handleNewUDPFlow(_ flow: NEAppProxyUDPFlow, initialRemoteEndpoint remoteEndpoint: NWEndpoint) -> Bool {
        let appID = flow.metaData.sourceAppSigningIdentifier
        
        if appsToManage!.contains(appID) {
            Logger.log.info("\(appID) Managing a new UDP flow")
            Task.detached(priority: .medium) {
                self.manageUDPFlow(flow, appID)
            }
            return true
        }
        return false
    }
    
    private func manageUDPFlow(_ flow: NEAppProxyUDPFlow, _ appID: String) {
        flow.open(withLocalEndpoint: nil) { error in
            if (error != nil) {
                Logger.log.error("Error: \(appID) \"\(error!.localizedDescription)\" in UDP flow open()")
                return
            }
            
            let socket = Socket(transportProtocol: TransportProtocol.UDP,
                                          appID: appID)
            var result = true
            if !socket.create() {
                Logger.log.error("Error: Failed to create \(appID)'s UDP socket")
                result = false
            }
            if !socket.bindToNetworkInterface(interfaceName: self.networkInterface!) {
                Logger.log.error("Error: Failed to bind \(appID)'s UDP socket")
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
            
            Task.detached(priority: .high) {
                let semaphore = DispatchSemaphore(value: 0)
                while (socket.status != .closed) {
                    UDPIO.handleRead(flow, socket, semaphore)
                    semaphore.wait()
                }
            }
            Task.detached(priority: .high) {
                let semaphore = DispatchSemaphore(value: 0)
                while (socket.status != .closed) {
                    UDPIO.handleWrite(flow, socket, semaphore)
                    semaphore.wait()
                }
            }
        }
    }
}
