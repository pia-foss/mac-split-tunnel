import Foundation

/**
The ProxyApp protocol describes the public API for
the class that send the requests to the network extension.
 */
protocol ProxyApp {
    // Send a request (OSSystemExtensionRequest) to activate the system extension.
    //
    // The user will be prompted to enter the password.
    // After that, a popup will appear explaining that the Proxy needs to be
    // allowed in the Privacy & Security settings.
    //
    // This function needs to be called just once, during first installation/use.
    // It will need to be called again, if the proxy has changed.
    // This means everytime during development and in production if a new version
    // of the proxy has been shipped
    func activateExtension() -> Bool
    
    // Send a request (OSSystemExtensionRequest) to deactivate the system extension.
    //
    // The user will be prompted to enter the password.
    // The extension is uninstalled from the system.
    // It will no longer be listed when running:
    // `systemextensionsctl list`.
    //
    // This also removes the Proxy entry from
    // system settings/Network/VPN & Filters/Filters & Proxies.
    //
    // This needs to be called only when the user is uninstalling the VPN client.
    // There is no need to call this function when a new version is shipped,
    // calling `activateExtension()` replaces the old extension with the new one
    // (as long as they have the same name)
    func deactivateExtension() -> Bool
    
    // Load the existing Proxy, if it is present in
    // system settings/Network/VPN & Filters/Filters & Proxies.
    //
    // If the extension has never been activated and run,
    // or if it has been deactivated with `deactivateExtension()`,
    // a new Proxy configuration will be installed
    func loadOrInstallProxyManager() -> Bool
    
    // Send a request to start the ProxyExtension process
    //
    // This will trigger the `startProxy()` function in the
    // NETransparentProxyProvider subclass
    func startProxy() -> Bool
    
    // Send a request to stop the ProxyExtension process
    //
    // This will trigger the `stopProxy()` function in the
    // NETransparentProxyProvider subclass.
    //
    // Stopping the tunnel is INCREDIBLY slow (for some reason).
    // It takes 5+ seconds for it to actually fully stop.
    // While disconnecting, the proxy is still working as if it was active.
    // After the stop procedure is completed, the extension process is killed
    func stopProxy() -> Bool
    
    // Pass an array of strings, containing all the bundle ID names of the apps
    // that will be managed by the Proxy.
    //
    // To get the bundle ID of an app, knowing its name use this command:
    // `osascript -e 'id of app "Google Chrome"'`
    func setManagedApps(apps: [String]) -> Void
}
