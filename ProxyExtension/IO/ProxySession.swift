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
    // End an existing proxy session (just calls through to terminateProxySession)
    func terminate() -> Void
    // Return the id for a given session (used for tracing)
    func identifier() -> IDGenerator.ID
    // Number of bytes transmitted and received
    var txBytes: UInt64 { get set }
    var rxBytes: UInt64 { get set }

    static func terminateProxySession(flow: Flow, channel: Channel) -> Void
}

extension ProxySession {
    static func terminateProxySession(flow: Flow, channel: Channel) -> Void {
        flow.closeReadAndWrite()
        // Ensure we execute the close in the same event loop as the channel
        channel.eventLoop.execute {
            guard channel.isActive else {
                return
            }
            channel.close().whenFailure { error in
                // Not much we can do here other than trace it
                log(.error, "Failed to close the channel: \(error)")
            }
        }
    }
}
