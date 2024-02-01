//
//  MockChannel.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 14/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NIO

// Mocks a NIO Channel
@testable import SplitTunnelProxyExtensionFramework
final class MockChannel: SessionChannel, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    // Required by SessionChannel
    var allocator: NIOCore.ByteBufferAllocator = ByteBufferAllocator()
    var pipeline: NIOCore.ChannelPipeline = ChannelPipeline(channel: EmbeddedChannel())
    var isActive: Bool
    let eventLoop: EventLoop = EmbeddedEventLoop()

    // A configurable option - determines whether the writeAndFlush() call succeeds. 
    // This allows us to change mock behaviour in tests to verify success/failure code paths.
    let successfulWrite: Bool

    // Allow the mock to be configurable
    // * isActive - whether the channel is active (this is checked when the channel is shutdown)
    // * successfulWrite - whether writeAndFlush returns a succeeded or failed future - a failed future
    // is unrecoverable so should result in early-exits in tests
    init(isActive: Bool, successfulWrite: Bool) {
        self.isActive = isActive
        self.successfulWrite = successfulWrite
    }

    func writeAndFlush<T>(_ any: T) -> NIOCore.EventLoopFuture<Void> {
        record(args: [any])
        switch successfulWrite {
        case true:
            return eventLoop.makeSucceededVoidFuture()
        case false:
            return eventLoop.makeFailedFuture(NSError(domain: "com.pia.vpn.error", code: 0, userInfo: nil))
        }
    }
    
    func close() -> NIOCore.EventLoopFuture<Void> {
        record()
        return eventLoop.makeSucceededVoidFuture()
    }
}
