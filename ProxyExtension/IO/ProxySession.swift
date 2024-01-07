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
    func start() -> EventLoopFuture<Channel>
    // End an existing proxy session
    func terminate() -> Void
    // Return the id for a given session (used for tracing)
    func identifier() -> IDGenerator.ID
}
