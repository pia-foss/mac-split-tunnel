import Foundation
import NetworkExtension

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
        let auditToken = flow.metaData.sourceAppAuditToken

        // A condition could be added here to achieve inverse split tunnelling.
        // Given the list of apps, we could either:
        // - manage the flows of ONLY the apps in the list
        // - manage the flows of ALL the OTHER apps, EXCEPT the ones in the list.
        let appPath = processPathFromAuditToken(token: auditToken)
        if appsToManage!.contains(appID) || appsToManage!.contains(where: { appPath.hasPrefix($0) }) {
            if let tcpFlow = flow as? NEAppProxyTCPFlow {
                Logger.log.info("\(appID) Managing a new TCP flow")
                Task.detached(priority: .medium) {
                    self.manageNewTCPFlow(tcpFlow, appID)
                }
                return true
            } else {
                Logger.log.error("Error: \(appID)'s UDP flow caught by handleNewFlow()")
            }
        }
        return false
    }

    private func processPathFromAuditToken(token: Data?) -> String {
        guard let auditToken = token else {
            Logger.log.warning("Audit token is nil")
            return ""
        }

        var pid: pid_t = 0

        auditToken.withUnsafeBytes { bytes in
            let auditTokenValue = bytes.bindMemory(to: audit_token_t.self).baseAddress!.pointee
            audit_token_to_au32(auditTokenValue, nil, nil, nil, nil, nil, &pid, nil, nil)

        }

        if(pid != 0) {
            guard let path = getProcessPath(pid: pid) else {
                Logger.log.warning("Found a process with pid \(pid) but could not convert to a path")
                return ""
            }
            
            Logger.log.info("Found a process with pid \(pid) and path \(path)")

            return path
        }
        else {
            Logger.log.warning("Could not get a pid from the audit token")
            return ""
        }
    }

    private func manageNewTCPFlow(_ flow: NEAppProxyTCPFlow, _ appID: String) {
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
            
            log(.debug, "\(appID) Before launching TCP handleReadAndWrite() in fd \(socket.fileDescriptor)")
            self.ioLib.handleReadAndWrite(TransportProtocol.TCP, flow, socket)
            log(.debug, "\(appID) After launching TCP handleReadAndWrite() in fd \(socket.fileDescriptor)")
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
            
            log(.debug, "\(appID) Before launching UDP handleReadAndWrite() in fd \(socket.fileDescriptor)")
            self.ioLib.self.handleReadAndWrite(TransportProtocol.UDP, flow, socket)
            log(.debug, "\(appID) After launching UDP handleReadAndWrite() in fd \(socket.fileDescriptor)")
        }
    }
}
