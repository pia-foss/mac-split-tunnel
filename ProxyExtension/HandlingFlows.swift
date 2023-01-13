//
//  HandlingFlows.swift
//  SplitTunnelProxy
//
//  Created by Michele Emiliani on 13/01/23.
//  Copyright © 2023 PIA. All rights reserved.
//

import Foundation
import NetworkExtension
import os.log

@available(macOS 11.0, *)
extension STProxyProvider {
    
    // This method is called by the system whenever an app that
    // matches the current App Proxy configuration’s app rules
    // creates a socket or sends/receives traffic on it.
    // returns:
    //   true  -> to handle a new flow
    //   false -> (for NETransparentProxyProvider)
    //            to let the system handle the flow
    //   false -> (for NEAppProxyProvider or NEDNSProxyProvider)
    //            the flow is discarded by the system
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        os_log("handling new flow!")
        
        // the name of the application
        let appID = flow.metaData.sourceAppSigningIdentifier
    
        // flows that I want to handle
        // apps IDs:
        // ["com.google.Chrome.helper", "org.mozilla.firefox"]
        let flowToHandle = ["org.mozilla.firefox"]
        
        if flowToHandle.contains(appID) {
            manageFlow(flow)
            
            // returning true means wanting to handle the flow
            return true
        }
        
        // letting all other flows go through the default system routing
        // that means they are going through the vpn, when it is active on the system
        return false
    }
    
    private func manageFlow(_ flow: NEAppProxyFlow) -> Void {
        
        // check if the connection state is not "connected"
        if self.connection!.state != .connected {
            os_log("Connection to local server not active!")
            return
        }
        
        // info about the flow
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
            manageUDPFlow(UDPFlow)
        }
    }
    
    private func manageTCPFlow(_ flow: NEAppProxyTCPFlow) -> Void {
        // An NWHostEndpoint object that contains the address and port to
        // set as the local address and local port of the flow.
        // If the source application already specifed a local endpoint by
        // binding the socket, then this parameter is ignored.
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
        
        // closing the flow
        // TCPFlow.closeReadWithError(nil)
        // TCPFlow.closeWriteWithError(nil)
    }
    
    private func readTCPFlowData(_ flow: NEAppProxyTCPFlow) -> Void {
        flow.readData { (data, error) in
            if error == nil, let readData = data, !readData.isEmpty {
                
                self.connection!.write(readData, completionHandler: { connectionError in
                    if connectionError == nil {
                        self.readTCPFlowData(flow)
                    } else {
                        os_log("error during connection write! %s", connectionError.debugDescription)
                    }
                })
                
            } else {
                // Handle error case or the read that contains empty data.
                if error != nil {
                    os_log("error during flow read! %s", error.debugDescription)
                } else {
                    os_log("read no data during flow read!")
                }
            }
        }
    }
    
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
