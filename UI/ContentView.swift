import SwiftUI

struct ContentView: View {
    
    var proxyApp = ProxyAppDefault()
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Group {
                Text("PIA Split Tunnel proxy GUI")
                Button("Activate") {
                    proxyApp.setBypassApps(apps: ["com.privateinternetaccess.splittunnel.testapp", "net.limechat.LimeChat-AppStore", "org.mozilla.firefox", "/usr/bin/curl", "/usr/bin/nc"])
                    proxyApp.setVpnOnlyApps(apps: ["/opt/homebrew/bin/wget"])
                    proxyApp.setNetworkInterface(interface: "en0")
                    guard proxyApp.activateExtension() else {
                        fatalError("Failed to activate the extension")
                    }
                }
                Button("Deactivate") {
                    guard proxyApp.deactivateExtension() else {
                        fatalError("Failed to deactivate the extension")
                    }
                }
                Button("LoadOrInstallManager") {
                    guard proxyApp.loadOrInstallProxyManager() else {
                        fatalError("Failed to load or install the proxy manager")
                    }
                }
                Button("StartProxy") {
                    guard proxyApp.startProxy() else {
                        fatalError("Failed to start the proxy")
                    }
                }
                Button("StopProxy") {
                    guard proxyApp.stopProxy() else {
                        fatalError("Failed to stop the proxy")
                    }
                }
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
