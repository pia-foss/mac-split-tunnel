//
//  STProxyProvider.swift
//  ProxyExtension
//
//  Created by Michele Emiliani on 05/12/22.
//  Copyright © 2022 PIA. All rights reserved.
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
// the provider handles the remote side of the connection using
// an API such as NWConnection or nw_connection_t
// In order to forward packets to the proxy, you must directly
// connect to the proxy from handleNewFlow and directly transfer
// the flow of parameters to the corresponding socket.


// To test that all the flows get captured by the rules, change the
// STProxyProvider class to a NEAppProxyProvider and return false
// in handleNewFlow, then verify that no app can connect to the internet.
@available(macOS 11.0, *)
class STProxyProvider : NETransparentProxyProvider {
    
    private var localTunnelAddress: [Substring] = []
    var TCPFlowsToHandle: [NEAppProxyTCPFlow] = []
    var connection: NWTCPConnection?

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
        self.localTunnelAddress = serverAddressParts
        let tunnelRemoteAddress: String = String(serverAddressParts[0])
        let tunnelRemotePort: String = String(serverAddressParts[1])
        
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
        self.setTunnelNetworkSettings(settings) { [self] error in
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

            // Connect to the local server after the extension proxy
            // has started.
            self.connectToLocalServer(address: "127.0.0.1", port: "9001")
        }
    }
    
    private func connectToLocalServer(address: String, port: String) {
        let endpoint: NWEndpoint
        endpoint = NWHostEndpoint(hostname: address, port: port)
        self.connection = self.createTCPConnection(to: endpoint, enableTLS:false, tlsParameters:nil, delegate:nil)
        let state = self.connection!.state
    }
    
    // this function is called when the application calls the
    // manager.connection.stopTunnel function
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log(.debug, "proxy stopped!")
    }
}
