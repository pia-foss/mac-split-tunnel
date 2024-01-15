//
//  ProxySession.swift
//  SplitTunnelProxyExtension
//
//  Created by John Mair on 08/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NIO

protocol ProxySession {
    // Start a new proxy session
    func start() -> Void
    // End an existing proxy session (calls through to Self.terminateProxySession)
    func terminate() -> Void
    // Return the id for a given session (used for tracing)
    func identifier() -> IDGenerator.ID
}

extension ProxySession {
    static func terminateProxySession(id: IDGenerator.ID, channel: SessionChannel, flow: Flow) {
        log(.info, "id: \(id) Terminating the flow")
        log(.info, "id: \(id) Trying to shutdown the flow")
        flow.closeReadAndWrite()
        if channel.isActive {
            log(.info, "id: \(id) Trying to shutdown the channel")
            let closeFuture = channel.close()
            closeFuture.whenSuccess {
                log(.info, "id: \(id) Successfully shutdown channel")
            }
            closeFuture.whenFailure { error in
                // Not much we can do here other than trace it
                log(.error, "Failed to close the channel: \(error)")
            }
        }
    }
}
