import Foundation
import NetworkExtension
import os.log

// Creating TCP and UDP connections using NE API
@available(macOS 11.0, *)
extension STProxyProvider {
    
    public func createLocalUDPSession(address: String, port: String) -> NWUDPSession {
        let endpoint: NWEndpoint
        endpoint = NWHostEndpoint(hostname: address, port: port)
        return self.createUDPSession(to: endpoint, from: nil)
    }
    
    public func closeLocalUDPSession(session: NWUDPSession) -> Void {
        session.cancel()
    }
    
    public func createLocalTCPConnection(address: String, port: String) -> NWTCPConnection {
        let endpoint: NWEndpoint
        endpoint = NWHostEndpoint(hostname: address, port: port)
        return self.createTCPConnection(to: endpoint, enableTLS:false, tlsParameters:nil, delegate:nil)
    }
    
    public func closeLocalTCPConnection(connection: NWTCPConnection) -> Void {
        connection.cancel()
    }
}
