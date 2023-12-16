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
        guard isFlowIPv4(flow) else {
            return false
        }

        let appID = flow.metaData.sourceAppSigningIdentifier

        // A condition could be added here to achieve inverse split tunnelling.
        // Given the list of apps, we could either:
        // - manage the flows of ONLY the apps in the list
        // - manage the flows of ALL the OTHER apps, EXCEPT the ones in the list.
        if isSplitApp(appFlow: flow) {
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

    // MARK: Managing UDP flows
    // handleNewUDPFlow() is called whenever an application
    // creates a new UDP socket.
    override func handleNewUDPFlow(_ flow: NEAppProxyUDPFlow, initialRemoteEndpoint remoteEndpoint: NWEndpoint) -> Bool {
        guard isFlowIPv4(flow) else {
            return false
        }

        let appID = flow.metaData.sourceAppSigningIdentifier

        if isSplitApp(appFlow: flow) {
            Logger.log.info("\(appID) Managing a new UDP flow")
            Task.detached(priority: .medium) {
                self.manageUDPFlow(flow, appID)
            }
            return true
        }
        return false
    }

    // Should the app be split from default traffic?
    private func isSplitApp(appFlow: NEAppProxyFlow) -> Bool {
        let appID = appFlow.metaData.sourceAppSigningIdentifier

        // First try the app id
        if appsToManage!.contains(appID) {
            return true
        }
        // Failing that, try using the audit token
        else {
            let auditToken = appFlow.metaData.sourceAppAuditToken

            // Ensure we can get a path
            guard let path = pathFromAuditToken(token: auditToken) else {
                return false
            }

            // Requires an exact match for the app path - so a complete path to the executable is required.
            // Case is ignored as macOS is a case-insensitive OS
            return appsToManage!.contains(where: { path.lowercased() == $0.lowercased() })
        }
    }

    // Is a given flow IPv4 ?
    private func isFlowIPv4(_ flow: NEAppProxyFlow) -> Bool {
        let hostName = flow.remoteHostname ?? ""
        // Check if the address is an IPv6 address, and negate it. IPv6 addresses always contain a ":"
        // We can't do the opposite (such as just checking for "." for an IPv4 address) due to IPv4-mapped IPv6 addresses
        // which are IPv6 addresses but include IPv4 address notation.
        return !hostName.contains(":")
    }

    // Given an audit token of an app flow - extract out the executable path for
    // the app generating the flow.
    private func pathFromAuditToken(token: Data?) -> String? {
        guard let auditToken = token else {
            Logger.log.warning("Audit token is nil")
            return nil
        }

        // The pid of the process behind the flow
        var pid: pid_t = 0

        // An audit token is opaque Data - but we can use it to extract the pid (and other things)
        // by converting it to an audit_token_t and then using libbsm APis to extract what we want.
        auditToken.withUnsafeBytes { bytes in
            let auditTokenValue = bytes.bindMemory(to: audit_token_t.self).baseAddress!.pointee

            // The full C signature is: audit_token_to_au32(audit_token_t atoken, uid_t *auidp, uid_t *euidp, gid_t *egidp, uid_t *ruidp, gid_t *rgidp, pid_t *pidp, au_asid_t *asidp, au_tid_t *tidp)
            // We pass in nil if we're not interested in that value - here we only want the PID, so that's all we request.
            audit_token_to_au32(auditTokenValue, nil, nil, nil, nil, nil, &pid, nil, nil)
        }

        guard pid != 0 else {
            Logger.log.warning("Could not get a pid from the audit token")
            return nil
        }

        // Get the executable path from the pid
        guard let path = getProcessPath(pid: pid) else {
            Logger.log.warning("Found a process with pid \(pid) but could not convert to a path")
            return nil
        }

        Logger.log.info("Found a process with pid \(pid) and path \(path)")
        return path
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
