import Foundation
import NetworkExtension
import os.log

// TODO: Handle DNS requests of managed (redirected) flows

// NETransparentProxyProvider is a subclass of NEAppProxyProvider.
// The behaviour is different compared to its super class:
// - Returning NO from handleNewFlow: and handleNewUDPFlow:initialRemoteEndpoint:
//   causes the flow to go to through the default system routing,
//   instead of being closed with a "Connection Refused" error.
// - NEDNSSettings and NEProxySettings specified in NETransparentProxyNetworkSettings are ignored.
//   Flows that match the includedNetworkRules within NETransparentProxyNetworkSettings
//   will use the system default DNS and proxy settings,
//   same as unmanaged (not redirected) flows.
// - Flows that are created using a "connect by name" API
//   (such as Network.framework or NSURLSession)
//   that match the includedNetworkRules will not bypass DNS resolution.
//
// The provider handles the remote side of the connection using
// an API such as NWConnection or nw_connection_t
// In order to forward packets to the proxy, you must directly
// connect to the proxy from handleNewFlow and directly transfer
// the flow of parameters to the corresponding socket.
//
//
// To test that all the flows get captured by the rules, change the
// STProxyProvider class to a NEAppProxyProvider and return false
// in handleNewFlow, then verify that no app can connect to the internet.
@available(macOS 11.0, *)
class STProxyProvider : NETransparentProxyProvider {
    
    // MARK: Proxy Properties
    var appsToManage: [String]?
    var address: String?
    var port: String?
    var connection: NWTCPConnection?
    // TODO: Check why we save this array
    // Do we need this?
    // Maybe map this array in a hash map with the app name as key?
    var TCPFlowsToHandle: [NEAppProxyTCPFlow] = []
    var UDPFlowsToHandle: [NEAppProxyUDPFlow] = []

    // MARK: Proxy Functions
    // This function is called when the ProxyApp process calls the
    // startTunnel() function
    override func startProxy(options: [String : Any]?, completionHandler: @escaping (Error?) -> Void) {
        os_log(.debug, "proxy extension started!")
        
        guard let address = options!["localProxyConnectionAddress"] as? String else {
            os_log(.error, "cannot find localProxyConnectionAddress in options")
            return
        }
        self.address = address
        guard let port = options!["localProxyConnectionPort"] as? String else {
            os_log(.error, "cannot find localProxyConnectionPort in options")
            return
        }
        self.port = port
        guard let appsToManage = options!["appsToManage"] as? [String] else {
            os_log(.error, "cannot find appsToManage in options")
            return
        }
        self.appsToManage = appsToManage
        
        // Initiating the rules.
        // We want to be "notified" of all flows, so we can decide which to manage,
        // based on the flow's app name.
        // We could also be limiting the flows that we get notified of.
        // Right now it seems best to just include everything.
        //
        // Only outbound traffic is supported in NETransparentProxyNetworkSettings
        // TODO: This needs to be verified
        var rules:[NENetworkRule] = []
        let ruleAllTCP = NENetworkRule(remoteNetwork: nil, remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .TCP, direction: .outbound)
        let ruleAllUDP = NENetworkRule(remoteNetwork: nil, remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .UDP, direction: .outbound)
        rules.append(ruleAllTCP)
        rules.append(ruleAllUDP)

        // Setting the NETransparentProxyNetworkSettings for the extension process
        // Using the same server address used in NETransparentProxyManager
        let settings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: address)
        settings.includedNetworkRules = rules
        settings.excludedNetworkRules = nil
        
        // These settings are also available.
        // Leaving them here just as a note.
        //
        // let dnsSettings = NEDNSSettings()
        // settings.dnsSettings = dnsSettings
        // let proxySettings = NEProxySettings()
        // settings.proxySettings = proxySettings
        
        // TODO: !!!
        // TODO: This part need heavy changes.
        // TODO: !!!
        // This connection must be established with another component.
        // Let's call it localProxy (for the lack of a better name).
        // This component will receive, via this connection, all the flows
        // (UDP and TCP network traffic) of the managed apps.
        // We could either:
        //
        // - Use multiple connections, one for each managed application.
        //   This will differentiate different apps' flows
        //   based on the connection port.
        //
        // - Use a single connection and send all the flows of
        //   all the managed apps to it.
        //   We would need to differentiate between different applications.
        //   Custom headers can be used to wrap the packages.
        //   That packages would need to be wrapped
        //   in the ProxyExtension process
        //   and then unwrapped in the localProxy process.
        //
        // Now are just choosing a random port and listening on that port
        // using netcat.
        // Consider using a UDP connection or UNIX socket for better performance.
        // (This can also be improved at a later stage)
        self.connection = self.createLocalTCPConnection(address: address, port: port)
        os_log(.debug, "initiated connection to localProxy")
        // TODO: Check status of this connection
        // What happens if no process is listening on that port?
        // If that is the case, the connection.state will never move to .Connected
        // We might wanna check if that is the case, using a closure
        // and also add a timeout to throw an error if that does not happen
        // Q: Do we need to call this function in the setTunnelNetworkSettings
        //         closure?
        
        // Sending the desired settings to the ProxyExtension process.
        // If the setting are not correct, an error will be thrown.
        self.setTunnelNetworkSettings(settings) { [] error in
            if (error != nil) {
                let errorString = error.debugDescription
                print(errorString)
                os_log(.debug, "error in setTunnelNetworkSettings: %s!", errorString)
                completionHandler(error)
                return
            }
            
            // This is needed in order to make the proxy connect.
            // If omitted the proxy will hang in the "Connecting..." state.
            completionHandler(nil)
        }
    }
    
    // this function is called when the application calls the
    // manager.connection.stopTunnel function
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        closeLocalTCPConnection(connection: self.connection!)
        os_log(.debug, "proxy stopped!")
    }
    
    // MARK: Managing the connection
    
    private func createLocalUDPSession(address: String, port: String) -> NWUDPSession {
        let endpoint: NWEndpoint
        endpoint = NWHostEndpoint(hostname: address, port: port)
        return self.createUDPSession(to: endpoint, from: nil)
    }
    
    private func closeLocalUDPSession(session: NWUDPSession) -> Void {
        session.cancel()
    }
    
    private func createLocalTCPConnection(address: String, port: String) -> NWTCPConnection {
        let endpoint: NWEndpoint
        endpoint = NWHostEndpoint(hostname: address, port: port)
        return self.createTCPConnection(to: endpoint, enableTLS:false, tlsParameters:nil, delegate:nil)
    }
    
    private func closeLocalTCPConnection(connection: NWTCPConnection) -> Void {
        connection.cancel()
    }
}
