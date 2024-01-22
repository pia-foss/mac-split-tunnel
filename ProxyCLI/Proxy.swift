import Foundation
import NetworkExtension
import ArgumentParser

let proxyManagerName = "PIA Split Tunnel"
let serverAddress = "127.0.0.1"

enum ManagerLoadingError: Error {
    case oopsie
    // Add other cases as needed
}

extension ProxyCLI {
    struct Proxy: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "proxy",
            abstract: "Manage the proxy.",
            subcommands: [Start.self, Stop.self, Status.self])
    }
}


extension ProxyCLI.Proxy {
    struct Start: AsyncParsableCommand {
        static var configuration
            = CommandConfiguration(
                commandName: "start",
                abstract: "Start the split tunnel proxy."
            )

        @Option(help: "Apps to bypass")
        var bypassApps: [String] = ["org.mozilla.firefox"]
        
        @Option(help: "Apps to enforce vpn use")
        var vpnOnlyApps: [String] = [String]()
        
        @Option(help: "Interface to send packages when bypassing")
        var bypassInterface: String = "en0"
        
        @Option(help: "Where to store system extension logs")
        var sysExtLogFile: String = "/tmp/STProxy.log"
        
        @Option(help: "Log level for the system extension logs")
        var sysExtLogLevel: String = "info"

        mutating func run() throws {
            try startProxy()
        }
        
        func startProxy() throws {
            let semaphore = DispatchSemaphore(value: 0)
            var proxyManager = loadProxyManagerSynchronously()

            if proxyManager == nil {
                proxyManager = createManager()
            }
            proxyManager!.saveToPreferences { errorSave in
                proxyManager!.loadFromPreferences { errorLoad in
                    // might want to refactor this code since the return value of startProxy()
                    // cannot show if an error occurred in these closures
                    if errorSave != nil || errorLoad != nil {
                        print("error while loading preferences!")
                        semaphore.signal()
                        return
                    }
                    
                    // The NETunnelProviderSession API is used to control network tunnel
                    // services provided by NETunnelProvider implementations.
                    if let session = proxyManager!.connection as? NETunnelProviderSession {
                        do {
                            // This function is used to start the tunnel (the proxy)
                            // passing it the following settings
                            try session.startTunnel(options: [
                                "bypassApps" : self.bypassApps,
                                "vpnOnlyApps" : self.vpnOnlyApps,
                                "networkInterface" : self.bypassInterface,
                                "serverAddress" : serverAddress,
                                "logFile" : sysExtLogFile,
                                "logLevel" : sysExtLogLevel,
                                "routeVpn" : true,
                                "connected" : true,
                                // The name of the unix group pia whitelists in the firewall
                                // This may be different when PIA is white-labeled
                                "whitelistGroupName" : "piavpn"
                            ] as [String : Any])
                        } catch {
                            print("startProxy error!")
                            print(error)
                        }
                    } else {
                        print("error getting the proxy manager connection")
                    }
                    semaphore.signal()
                }
            }
            _ = semaphore.wait(timeout: .now() + 120)
        }
    }

    struct Stop: ParsableCommand {
        static var configuration
            = CommandConfiguration(
                commandName: "stop",
                abstract: "Stop the split tunnel proxy.")

        mutating func run() throws {
            try stopProxy()
        }
        
        func stopProxy() throws {
            let proxyManager = loadProxyManagerSynchronously()
            
            if proxyManager == nil {
                print("No manager found")
                return
            }
            
            if let session = proxyManager!.connection as? NETunnelProviderSession {
                session.stopTunnel()
            } else {
                print("error getting the proxy manager connection")
            }
        }

    }
    
    struct Status: ParsableCommand {
        static var configuration
            = CommandConfiguration(
                commandName: "status",
                abstract: "Get proxy status.")
        
        static let StatusMap = [
            NEVPNStatus.connected : "connected",
            NEVPNStatus.connecting: "connecting",
            NEVPNStatus.disconnected: "disconnected",
            NEVPNStatus.disconnecting: "disconnecting",
            NEVPNStatus.invalid: "invalid",
            NEVPNStatus.reasserting: "reasserting",
        ] as [NEVPNStatus: String]
        
        mutating func run() throws {
            try getProxyStatus()
        }
        
        func getProxyStatus() throws {
            let proxyManager = loadProxyManagerSynchronously()
            
            if proxyManager == nil {
                print("uninstalled")
                return
            }

            if let session = proxyManager!.connection as? NETunnelProviderSession {
                print(Status.StatusMap[session.status]!)
            }
        }
    }
}


func loadProxyManagerSynchronously() -> NETransparentProxyManager? {
    let semaphore = DispatchSemaphore(value: 0)
    var proxyManager: NETransparentProxyManager? = nil

    NETransparentProxyManager.loadAllFromPreferences() { loadedManagers, error in
        if let error = error {
            print("error while loading manager: \(error)")
        } else if let managers = loadedManagers, !managers.isEmpty {
            if managers.count == 1 {
                proxyManager = managers.first
            } else {
                print("ERROR: found more than 1 manager!")
            }
        }
        semaphore.signal()
    }

    _ = semaphore.wait(timeout: .now() + 120)

    return proxyManager
}

private func createManager() -> NETransparentProxyManager {
    let proxyManager = NETransparentProxyManager()
    proxyManager.localizedDescription = proxyManagerName
    
    let tunnelProtocol = NETunnelProviderProtocol()
    // This must match the app extension bundle identifier
    tunnelProtocol.providerBundleIdentifier = splitTunnelBundleId
    // As for NETransparentProxyNetworkSettings unsure about the meaning of
    // this setting in the context of a NETransparentProxy.
    // Docs say it should be the VPN address
    //
    // Setting it to localhost for now, until a 'proper' solution is found
    tunnelProtocol.serverAddress = serverAddress
    proxyManager.protocolConfiguration = tunnelProtocol
    
    proxyManager.isEnabled = true
    
    return proxyManager
}

