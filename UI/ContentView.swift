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
            Group {
                Text("DNS Proxy commands")
                Button("startDNSProxy") {
                    guard proxyApp.startDNSProxy() else {
                        fatalError("Failed to start the DNS proxy")
                    }
                }
                Button("stopDNSProxy") {
                    guard proxyApp.stopDNSProxy() else {
                        fatalError("Failed to stop the DNS proxy")
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
