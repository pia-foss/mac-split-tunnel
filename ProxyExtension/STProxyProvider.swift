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

    // MARK: Proxy Functions
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
        
        // let dnsSettings = NEDNSSettings()
        // settings.dnsSettings = dnsSettings
        // let proxySettings = NEProxySettings()
        // settings.proxySettings = proxySettings

        self.connection = self.createLocalTCPConnection(address: address, port: port)
        
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
    
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        closeLocalTCPConnection(connection: self.connection!)
        os_log(.debug, "proxy stopped!")
    }
}
