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
    
    // all the custom settings that we pass to the ProxyExtension process
    func initSettings() {
        // We want to handle the flow of these apps
        //
        // Use this command to get the bundle ID of an app
        // $ osascript -e 'id of app "Google Chrome"'
        self.appsToManage = ["com.privateinternetaccess.splittunnel.testapp"]
    }
    
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
    
    func loadManager() -> Void {
        os_log("loading the extension manager!")
        
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
               self.createManager()
            }
        }
    }
    
    func createManager() -> Void {
        if self.manager != nil {
            os_log("manager already created!")
            return
        }
        os_log("creating manager!")
        
        let newManager = NETransparentProxyManager()
        newManager.localizedDescription = "MyTransparentProxy"
        
        // Configure a VPN protocol to use a Packet Tunnel Provider
        let tunnelProtocol = NETunnelProviderProtocol()
        // This must match the app extension bundle identifier
        tunnelProtocol.providerBundleIdentifier =
            "com.privateinternetaccess.splittunnel.poc.extension"
        // As for NETransparentProxyNetworkSettings unsure about the meaning of
        // this setting in the context of a NETransparentProxy.
        // Docs say it should be the VPN address
        //
        // Setting it to localhost for now, until a 'proper' solution is found
        tunnelProtocol.serverAddress = "127.0.0.1"
        newManager.protocolConfiguration = tunnelProtocol
        
        // Enable the manager by default
        newManager.isEnabled = true
        
        self.manager = newManager
        os_log("manager created!")
    }
        
    func startTunnel(manager: NETransparentProxyManager) {
        os_log("starting tunnel!")

        manager.saveToPreferences { errorSave in
            manager.loadFromPreferences { errorLoad in
                if errorSave != nil || errorLoad != nil {
                    os_log("error while loading preferences!")
                }
                os_log("saved and loaded preferences!")
                
                // The NETunnelProviderSession API is used to control network tunnel
                // services provided by NETunnelProvider implementations.
                if let session = manager.connection as? NETunnelProviderSession {
                    do {
                        // This function is used to start the tunnel (the proxy)
                        // passing it the following settings
                        try session.startTunnel(options: [
                            "appsToManage" : self.appsToManage
                        ] as [String : Any])
                    } catch {
                        os_log("startTunnel error!")
                        print(error)
                    }
                }
            }
        }
    }
    
    func stopTunnel(manager: NETransparentProxyManager) {
        os_log("stopping tunnel!")
        
        let session = manager.connection as! NETunnelProviderSession
        session.stopTunnel()
    }
}
