import Foundation
import NetworkExtension
import SystemExtensions
import os.log

/**
The ProxyAppDefault class implements the ProxyApp protocol.
The process using this class will run in the user space, acting as the "frontend"
for the root network extension process
 */
class ProxyAppDefault : ProxyApp {
    var proxyManager: NETransparentProxyManager?
    var extensionRequestDelegate = ExtensionRequestDelegate()
    var appsToManage: [String] = []
    var networkInterface: String = ""
    static let proxyManagerName = "PIA Split Tunnel Proxy"
    static let serverAddress = "127.0.0.1"

    func setManagedApps(apps: [String]) -> Void {
        self.appsToManage = apps
    }
    
    func setNetworkInterface(interface: String) -> Void {
        self.networkInterface = interface
    }

    func activateExtension() -> Bool {
        os_log("activating extension!")
        
        guard let extensionIdentifier = getExtensionBundleID().bundleIdentifier else {
            os_log("cannot find the extension bundle ID!")
            return false
        }
        os_log("found the extension: %s", extensionIdentifier)
        
        let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        activationRequest.delegate = extensionRequestDelegate
        OSSystemExtensionManager.shared.submitRequest(activationRequest)
        os_log("extension activation request sent!")
        return true
    }

    func deactivateExtension() -> Bool {
        os_log("deactivating extension!")
        
        guard let extensionIdentifier = getExtensionBundleID().bundleIdentifier else {
            os_log("cannot find the extension to deactivate!")
            return false
        }
        os_log("found the extension: %s", extensionIdentifier)
        
        let deactivationRequest = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        deactivationRequest.delegate = extensionRequestDelegate
        OSSystemExtensionManager.shared.submitRequest(deactivationRequest)
        os_log("extension deactivation request sent!")
        return true
    }

    func loadOrInstallProxyManager() -> Bool {
        tryLoadProxyManager() {
            if self.proxyManager == nil {
                self.createManager()
            }
        }
        return true
    }

    private func tryLoadProxyManager(completion: @escaping () -> Void) {
        os_log("trying to load an existing proxy manager!")
        
        NETransparentProxyManager.loadAllFromPreferences() { loadedManagers, error in
            if error != nil {
                os_log("error while loading manager!")
            } else if loadedManagers!.isEmpty {
                os_log("no managers found")
            } else if loadedManagers!.count == 1 {
                self.proxyManager = loadedManagers!.first
                os_log("manager loaded!")
            } else {
                os_log("ERROR: found more than 1 manager!")
            }
            completion()
        }
    }

    private func createManager() {
        os_log("creating manager!")
        
        self.proxyManager = NETransparentProxyManager()
        self.proxyManager!.localizedDescription = ProxyAppDefault.proxyManagerName
        
        let tunnelProtocol = NETunnelProviderProtocol()
        // This must match the app extension bundle identifier
        tunnelProtocol.providerBundleIdentifier = getExtensionBundleID().bundleIdentifier
        // As for NETransparentProxyNetworkSettings unsure about the meaning of
        // this setting in the context of a NETransparentProxy.
        // Docs say it should be the VPN address
        //
        // Setting it to localhost for now, until a 'proper' solution is found
        tunnelProtocol.serverAddress = ProxyAppDefault.serverAddress
        self.proxyManager!.protocolConfiguration = tunnelProtocol
        
        self.proxyManager!.isEnabled = true
        
        os_log("manager created!")
    }

    func startProxy() -> Bool {
        os_log("starting proxy extension!")
        
        if self.proxyManager == nil {
            os_log("no manager is found!")
            return false
        }

        self.proxyManager!.saveToPreferences { errorSave in
            self.proxyManager!.loadFromPreferences { errorLoad in
                // might want to refactor this code since the return value of startProxy()
                // cannot show if an error occurred in these closures
                if errorSave != nil || errorLoad != nil {
                    os_log("error while loading preferences!")
                    return
                }
                
                // The NETunnelProviderSession API is used to control network tunnel
                // services provided by NETunnelProvider implementations.
                if let session = self.proxyManager!.connection as? NETunnelProviderSession {
                    do {
                        // This function is used to start the tunnel (the proxy)
                        // passing it the following settings
                        try session.startTunnel(options: [
                            "appsToManage" : self.appsToManage,
                            "networkInterface" : self.networkInterface,
                            "serverAddress" : ProxyAppDefault.serverAddress,
                            "logFile" : "/tmp/STProxy.log",
                            "logLevel" : "debug"
                        ] as [String : Any])
                    } catch {
                        os_log("startProxy error!")
                        print(error)
                    }
                } else {
                    os_log("error getting the proxy manager connection")
                }
            }
        }
        
        return true
    }

    func stopProxy() -> Bool {
        os_log("stopping proxy extension!")
        
        if self.proxyManager == nil {
            os_log("no manager is found!")
            return false
        }
        
        if let session = self.proxyManager!.connection as? NETunnelProviderSession {
            session.stopTunnel()
        } else {
            os_log("error getting the proxy manager connection")
            return false
        }
        
        return true
    }
}
