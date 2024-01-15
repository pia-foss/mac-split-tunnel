//
//  SessionChannelProtocol.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 15/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NIO

// Simplified interface for a NIO Channel - we use this instead of a real NIO Channel
// as it's a much simpler interface, contains everything we use - and
// is therefore much easier to use when stubbing/mocking in tests
// NIO Channel also conforms to this protocol.
protocol SessionChannel {
    var allocator: ByteBufferAllocator { get }
    var pipeline: ChannelPipeline { get }
    var isActive: Bool { get }
    func writeAndFlush<T>(_ any: T) -> EventLoopFuture<Void>
    func close() -> EventLoopFuture<Void>
}
