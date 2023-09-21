import Foundation
import NetworkExtension
import SystemExtensions
import os.log

/**
In this file we manage the transparent proxy extension proxy
This code is executed by our ProxyApp
which is the "frontend" for the actual ProxyExtension process
 */
extension ViewController {
    
    // all the settings needed for the transparent proxy
    func initSettings() {
        // tunnel server address and port
        self.serverAddress = "127.0.0.1"
        self.serverPort = "9000"
        // not used at the moment
        self.rulesHosts = ["0.0.0.0"]
    }
    
    // Start by activating the system extension
    // OSSystemExtensionRequest
    // A request to activate or deactivate a system extension.
    // Prompts user password and allow in system settings.
    // This needs to be called everytime the extension is modified
    func activateExtension() -> Void {
        os_log("activating extension!")
        
        guard let extensionIdentifier = extensionBundle.bundleIdentifier else {
            os_log("cannot find the extensionIdentifier!")
            return
        }
        os_log("found the extension: %s", extensionIdentifier)
        let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        activationRequest.delegate = self
        OSSystemExtensionManager.shared.submitRequest(activationRequest)
        os_log("extension activation request sent!")
    }
    
    // Deactivates the extension, effectively uninstalling it.
    // The extension no longer is listed in
    // `systemextensionsctl list`.
    // Make sure that this also removes "MyTransparentProxy" from
    // the networks in system settings.
    // There is no need to do this every time, calling activate
    // replaces the old extension with the new one,
    // if it has been modified
    func deactivateExtension() -> Void {
        os_log("deactivating extension!")
        
        guard let extensionIdentifier = extensionBundle.bundleIdentifier else {
            os_log("cannot find the extension to deactivate!")
            return
        }
        let deactivationRequest = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        deactivationRequest.delegate = self
        OSSystemExtensionManager.shared.submitRequest(deactivationRequest)
        os_log("extension deactivation request sent!")
    }
    
    // This can load the existing "MyTrasparentProxy", if present
    // in system settings/network.
    // Each NETunnelProviderManager instance corresponds to a single
    // VPN configuration stored in the Network Extension preferences.
    // Multiple VPN configurations can be created and managed by
    // creating multiple NETunnelProviderManager instances.
    func loadManager(completion: @escaping () -> Void) {
        os_log("loading the extension manager!")
        
        // TODO: Check this function
        initSettings()

        NETransparentProxyManager.loadAllFromPreferences() { loadedManagers, error in
            if error != nil {
                os_log("error while loading preferences!")
                return
            }
            
            guard let vpnManagers = loadedManagers else {
                os_log("error while loading managers!")
                return
            }
            
            if !vpnManagers.isEmpty {
                if vpnManagers.count == 1 {
                    self.manager = vpnManagers.first
                    os_log("manager loaded!")
                } else {
                    os_log("ERROR: found more than 1 manager!")
                }
            } else {
                os_log("ERROR: no managers found, creating one!")
                // The completion function is called if no previous extension
                // managers can be found.
                // Unless the extension is deactivated, creating it once and
                // loading all the following times is correct.
                // Upon an update of the app, it would be best to deactivate the
                // extension as a good practice.
                completion()
            }
        }
    }
    
    // A NETransparentProxyManager is created if none are present
    // already in the system
    func createManager() -> Void {
        if self.manager != nil {
            os_log("manager already created!")
            return
        }
        os_log("creating manager!")
        
        let newManager = NETransparentProxyManager()
        newManager.localizedDescription = "MyTransparentProxy"
        
        // Configure a VPN protocol to use a Packet Tunnel Provider
        let proto = NETunnelProviderProtocol()
            // This must match the app extension bundle identifier
            proto.providerBundleIdentifier = "com.privateinternetaccess.splittunnel.poc.extension"
            // In a classic VPN, this would be the IP address/url of the VPN server.
            // There is probably no concept here of a network interface since
            // this is a high level API.
            // The NE framework is providing a (sort of an) interface
            // Traffic is captured using general rules
            proto.serverAddress = self.serverAddress+":"+self.serverPort
            // Pass additional vendor-specific information to the tunnel
            proto.providerConfiguration = [:]
            // proxy settings to use for connections routed through the tunnel
//                let proxy = NEProxySettings()
//                proto.proxySettings = proxy
            proto.includeAllNetworks = false
            proto.excludeLocalNetworks = true
            // if YES, route rules for this tunnel will take precendence over
            // any locally-defined routes
            proto.enforceRoutes = false
        
        newManager.protocolConfiguration = proto
        
        // Enable the manager by default
        newManager.isEnabled = true
        
        self.manager = newManager
        os_log("manager created!")
    }
        
    // This function starts the the process
    // "com.privateinternetaccess.splittunnel.poc.extension"
    func startTunnel(manager: NETransparentProxyManager) {
        os_log("starting tunnel!")

        // This is needed in order to create the network settings item
        manager.saveToPreferences { error1 in
            manager.loadFromPreferences { error2 in
                if error1 != nil || error2 != nil {
                    os_log("error while loading preferences!")
                }
                os_log("saved and loaded preferences!")
                
                // The NETunnelProviderSession API is used to control network tunnel
                // services provided by NETunnelProvider implementations.
                // It is a subclass of NEVPNConnection, which implements the method
                // startVPNTunnel.
                if let session = manager.connection as? NETunnelProviderSession {
                    do {
//                        try session.sendProviderMessage(Data([1,2,3,4]))
                        // This function is used to start the tunnel using the configuration associated with this connection object. The tunnel connection process is started and this function returns immediately.
                        try session.startTunnel(options: [
//                            NEVPNConnectionStartOptionUsername: "user",
//                            NEVPNConnectionStartOptionPassword: "password",
                            "rulesHosts": self.rulesHosts
                        ] as [String : NSObject])
                    } catch {
                        os_log("startVPNTunnel error!")
                        print(error)
                    }
                }
            }
        }
    }
    
    // Disconnection can be quite slow, taking >5 seconds.
    // While disconnecting, the traffic acts as the proxy was active.
    // After the disconnection is completed, the process
    // "com.privateinternetaccess.splittunnel.poc.extension" is killed.
    func stopTunnel(manager: NETransparentProxyManager) {
        os_log("stopping tunnel!")
        
        let session = manager.connection as! NETunnelProviderSession
        session.stopTunnel()
    }
}


