import Foundation
import NetworkExtension
import os.log

@available(macOS 11.0, *)
extension STProxyProvider {
    
    // This method is called whenever an app that
    // matches the current App Proxy configuration’s app rules
    // sends TCP or UDP network traffic.
    // returns:
    //   true  -> to handle a new flow
    //   false -> (for NETransparentProxyProvider)
    //            to let the system handle the flow
    //   false -> (for NEAppProxyProvider or NEDNSProxyProvider)
    //            the flow is discarded and the connection is closed
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        // the name of the application to which this flow belongs
        let appID = flow.metaData.sourceAppSigningIdentifier
        
        os_log("deciding if we need to handle %s flow", appID)
        
        // A condition could be added here to achieve inverse split tunnelling.
        // Given the list of apps, we could either:
        // - manage the flows of ONLY the apps in the list
        // - manage the flows of ALL the OTHER apps, EXCEPT the ones in the list.
        //   (If implemented, this would need to be tested performance-wise)
        
        if appsToManage!.contains(appID) {
            redirectFlow(flow)
            
            // The flow of this app will be managed by the network extension
            // The objective is that this traffic goes through the physical
            // network interface.
            // As if all the sockets of this process were bound to that
            // interface.
            return true
        }
        
        // The flow of this app will be routed by the system as if the
        // transparent proxy was not there.
        // The idea is to run the extension only when we are connected to the vpn,
        // so that this traffic goes through the vpn virtual network interface.
        return false
    }
    
    private func redirectFlow(_ flow: NEAppProxyFlow) -> Void {
        // Check if the connection state is not "connected".
        // Ideally we have already checked that during extension init.
        // It is not bad to always check it here though, since the connection
        // might have been closed due to the localProxy process crashing or exiting
        if self.connection!.state != .connected {
            os_log("Connection to local server not active!")
            return
        }
        
        // read-only info about the flow
        // same as appID
        let description = flow.metaData.debugDescription
        // the PID of the process can be extracted from the sourceAppAuditToken
        let appAuditToken = flow.metaData.sourceAppAuditToken
        // the ip address destination of the connection, if present
        let remoteHostname = flow.remoteHostname
        // the network interface of the flow (en0)
        let nwInterface = flow.networkInterface?.description
        
        // NEAppProxyTCPFlow: An object for reading and writing data
        // to and from a TCP connection being proxied by the provider
        if let TCPFlow = flow as? NEAppProxyTCPFlow {
            // adding this flow to the vector containing all flows handled
            // by the transparent proxy provider
            TCPFlowsToHandle.append(TCPFlow)
            manageTCPFlow(TCPFlow)
        }
        else if let UDPFlow = flow as? NEAppProxyUDPFlow {
            UDPFlowsToHandle.append(UDPFlow)
            manageUDPFlow(UDPFlow)
        }
    }
    
    private func manageTCPFlow(_ flow: NEAppProxyTCPFlow) -> Void {
        // An NWHostEndpoint object that contains the address and port to
        // set as the local address and local port of the flow.
        // If the source application already specifed a local endpoint by
        // binding the socket, then this parameter is ignored.
        // TODO: Check why this variable is not used
        let localEndpoint: NWHostEndpoint
        
        // open() is used by an NEProvider implementation
        // to indicate to the system that the caller is ready
        // to start reading and writing to this flow.
        flow.open(withLocalEndpoint: nil) { error in
            if (error != nil) {
                os_log("error during flow open! %s", error.debugDescription)
            }
            
            self.readTCPFlowData(flow)
        }
        
        // close the flow when you dont want to read and write to it anymore
        // TCPFlow.closeReadWithError(nil)
        // TCPFlow.closeWriteWithError(nil)
    }
    
    // TODO: Check if this is the correct way of reading and writing to a connection.
    private func readTCPFlowData(_ flow: NEAppProxyTCPFlow) -> Void {
        flow.readData { data, error in
            if error == nil, let readData = data, !readData.isEmpty {
                self.connection!.write(readData, completionHandler: { connectionError in
                    if connectionError == nil {
                        self.writeTCPFlowData(flow)
                        self.readTCPFlowData(flow)
                    } else {
                        os_log("error during connection write! %s", connectionError.debugDescription)
                    }
                })
            } else {
                // Handle an error on the flow read.
                if error != nil {
                    os_log("error during flow read! %s", error.debugDescription)
                } else {
                    os_log("read no data during flow read!")
                }
            }
        }
    }
    
    private func writeTCPFlowData(_ flow: NEAppProxyTCPFlow) -> Void {
        self.connection!.readMinimumLength(1, maximumLength: 2048, completionHandler: { data, error in
            if error == nil, let writeData = data, !writeData.isEmpty {
                flow.write(writeData) { flowError in
                    if flowError == nil {
                        self.writeTCPFlowData(flow)
                    } else {
                        os_log("error during flow write! %s", flowError.debugDescription)
                    }
                }
            } else {
                // Handle an error on the connection read.
                if error != nil {
                    os_log("error during connection read! %s", error.debugDescription)
                } else {
                    os_log("read no data during connection read!")
                }
            }
        })
    }
    
    // TODO: This function is missing implementation
    private func manageUDPFlow(_ flow: NEAppProxyUDPFlow) -> Void {
        flow.open(withLocalEndpoint: flow.localEndpoint as? NWHostEndpoint) { error in
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
