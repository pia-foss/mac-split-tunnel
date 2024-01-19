import Foundation
import NIO

// Protocol for the ProxySession classes (ProxySessionTCP, ProxySessionUDP).
// These classes track a single proxy session for a connection from an originating app.
// They handle both the Flow from the originating app and the proxying of that flow to the corresponding
// NIO Channel, handling both reads and writes in both directions.
protocol ProxySession {
    // Start a new proxy session
    func start() -> Void
    // End an existing proxy session (calls through to Self.terminateProxySession)
    func terminate() -> Void
    // Return the id for a given session (used for tracing)
    func identifier() -> IDGenerator.ID
}

enum UnsupportedProtocol: Error {
    case IPv6(_ message: String)
}

extension ProxySession {
    // Called by a ProxySession class to kill a session.
    static func terminateProxySession(id: IDGenerator.ID, channel: SessionChannel, flow: Flow) {
        log(.info, "id: \(id) Terminating the flow")
        log(.info, "id: \(id) Trying to shutdown the flow")
        // Kill the flow
        flow.closeReadAndWrite()
        if channel.isActive {
            log(.info, "id: \(id) Trying to shutdown the channel")
            // Kill the NIO channel
            let closeFuture = channel.close()
            closeFuture.whenSuccess {
                log(.info, "id: \(id) Successfully shutdown channel")
            }
            closeFuture.whenFailure { error in
                // Not much we can do here other than trace it
                log(.error, "id: \(id) Failed to close the channel: \(error)")
            }
        }
    }
}
