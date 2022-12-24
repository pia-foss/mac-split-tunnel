//
//  AppProxyProvider.swift
//  SimpleFirewallExtension
//
//  Created by Michele Emiliani on 05/12/22.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation
import NetworkExtension
import os.log

// NETransparentProxyProvider derives from NEAppProxyProvider
// The NETransparentProxyProvider class has the following behavior
// differences from its super class NEAppProxyProvider:
//       - Returning NO from handleNewFlow: and handleNewUDPFlow:initialRemoteEndpoint: causes the flow to proceed to communicate directly with the flow's ultimate destination, instead of closing the flow with a "Connection Refused" error.
//         - NEDNSSettings and NEProxySettings specified within NETransparentProxyNetworkSettings are ignored. Flows that match the includedNetworkRules within NETransparentProxyNetworkSettings will use the same DNS and proxy settings that other flows on the system are currently using.
//         - Flows that are created using a "connect by name" API (such as Network.framework or NSURLSession) that match the includedNetworkRules will not bypass DNS resolution.
//
// To test that all the flows get captured by the rules, change the class to
// a NEAppProxyProvider and return false in handleNewFlow,
// then verify that no app can connect to the internet in any way.
@available(macOS 11.0, *)
class STProxyProvider : NETransparentProxyProvider {
//class STProxyProvider : NEAppProxyProvider {

    // this function is called when the application calls the
    // manager.connection.startTunnel function
    override func startProxy(options: [String : Any]?, completionHandler: @escaping (Error?) -> Void) {
        os_log(.debug, "proxy started!")
        
        // Using the same server address used in the protocol when creating the
        // NETransparentProxyManager, without the port
        let serverAddressParts = self.protocolConfiguration.serverAddress!.split(separator: ":")
        guard serverAddressParts.count == 2 else {
            return
        }
        let tunnelRemoteAddress: String = String(serverAddressParts[0])
        
        // settings the rules
        // Only outbound traffic is supported in NETransparentProxyNetworkSettings.
        var rules:[NENetworkRule] = []
        let ruleAllTCP = NENetworkRule(remoteNetwork: nil, remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .TCP, direction: .outbound)
        let ruleAllUDP = NENetworkRule(remoteNetwork: nil, remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .UDP, direction: .outbound)
        rules.append(ruleAllTCP)
        rules.append(ruleAllUDP)

        // NETransparentProxyNetworkSettings is used by
        // NEAppProxyProviders to communicate the desired network
        // settings for the proxy to the framework.
        let settings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: tunnelRemoteAddress)
        // An array of NENetworkRule objects that collectively specify the traffic
        // that will be routed through the transparent proxy
        settings.includedNetworkRules = rules
        settings.excludedNetworkRules = nil
        
        // Also these settings are available, check if they could
        // be useful
//        let dnsSettings = NEDNSSettings()
//        settings.dnsSettings = dnsSettings
//        let proxySettings = NEProxySettings()
//        settings.proxySettings = proxySettings
        
        // sending the desired settings to the NE framework
        // if they are wrong, an error will be thrown here
        self.setTunnelNetworkSettings(settings) { error in
            if (error != nil) {
                let errorString = error.debugDescription
                print(errorString)
                os_log(.debug, "error in setTunnelNetworkSettings: %s!", errorString)
                completionHandler(error)
                return
            }
            
            // This is needed in order to make the proxy connect.
            // If omitted the proxy will hang in the "Connecting..." state.
            // It will go to "Connected" only if there are no errors.
            completionHandler(nil)
        }
    }
    
    // this function is called when the application calls the
    // manager.connection.stopTunnel function
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // stopping the proxy
        os_log(.debug, "proxy stopped!")
    }
    
    // This method is called by the system whenever an app that
    // matches the current App Proxy configuration’s app rules
    // opens a new network connection.
    // returns:
    //   true  -> to handle a new flow
    //   false -> (for NETransparentProxyProvider)
    //            to let the system handle the flow
    //   false -> (for NEAppProxyProvider or NEDNSProxyProvider)
    //            the flow is discarded by the system
    //
    //  The proxy provider implementation indicates that the proxy is ready to handle flow data by calling -[NEAppProxyFlow openWithLocalEndpoint:completionHandler:] on the flow.
    // the provider handles the remote side of the connection using an API such as NWConnection or nw_connection_t
    // In order to forward packets to the proxy, you must directly connect to the proxy from handleNewFlow and directly transfer the flow of parameters to the corresponding socket.
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        os_log("handling new flow!")
        
        // the name of the application
        let appID = flow.metaData.sourceAppSigningIdentifier
        // same as appID
        let description = flow.metaData.debugDescription
        // the PID of the process can be extracted from the sourceAppAuditToken
        let appAuditToken = flow.metaData.sourceAppAuditToken
        // the ip address destination of the connection, if present
        let remoteHostname = flow.remoteHostname
        // the network interface of the flow (en0)
        let nwInterface = flow.networkInterface?.description
        var remote: String
        var local: String?
//        if appID == "com.google.Chrome.helper" {
        if appID == "org.mozilla.firefox" {
            if let TCPFlow = flow as? NEAppProxyTCPFlow {
                // An NWEndpoint object containing information about the intended remote endpoint of the flow.
                remote = TCPFlow.remoteEndpoint.description
                
                
                
                // localEndpoint The address and port that should be used as the local
                // endpoint of the socket associated with this flow.
                // If the source application already specifed a local endpoint by
                // binding the socket then this parameter is ignored.
                //
                
                let host = NWHostEndpoint(hostname: remote, port: "443")
                TCPFlow.open(withLocalEndpoint: host) { error in
                    if (error != nil) {
                        os_log("error during flow open!")
                    }
                    //callback code here
                }
                
                
                
                
                
            }
            else if let UDPFlow = flow as? NEAppProxyUDPFlow {
                local = UDPFlow.localEndpoint?.description
            }
            // returning true means wanting to handle the flow
            return true
        }
        
        // letting all other flows go through the default system routing
        return false
    }
}
