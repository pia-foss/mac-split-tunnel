//
//  MockChannel.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 14/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NIO

class MockChannel: SessionChannel, Mock {
    var methodsCalled: Set<String> = []

    var argumentsGiven: Dictionary<String, [Any]> = [:]

    var allocator: NIOCore.ByteBufferAllocator = ByteBufferAllocator()
    var pipeline: NIOCore.ChannelPipeline = ChannelPipeline(channel: EmbeddedChannel())
    var isActive: Bool
    let eventLoop: EventLoop = EmbeddedEventLoop()

    let successfulWrite: Bool

    // Allow the mock to be configurable
    // isActive - whether the channel is active (this is checked when the channel is shutdown)
    // successfulWrite - whether writeAndFlush returns a succeeded or failed future - a failed future
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
            return eventLoop.makeFailedFuture(NSError(domain: "com.privateinternetaccess.vpn.error", code: 0, userInfo: nil))
        }
    }
    
    func close() -> NIOCore.EventLoopFuture<Void> {
        record()
        return eventLoop.makeSucceededVoidFuture()
    }
}
