//
//  Channel+Extension.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 15/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NIO

// Wraps a NIO Channel - this is necessary in order to implement tests
// As the concrete channel classes, NIO.SocketChannel and NIO.DatagramChannel
// are not exposed so we can't just extend them with our SessionChannel protocol
// and we can't extend the NIO Channel (a protocol) with another protocol - only concrete classes
// can be extended.
final class ChannelWrapper: SessionChannel {
    let channel: Channel

    // Delegate to underlying channel, these are computed properties
    // but the 'get' is optional for read-only single expression properties
    var allocator: ByteBufferAllocator { channel.allocator }
    var pipeline: ChannelPipeline { channel.pipeline }
    var isActive: Bool { channel.isActive }

    init(_ channel: Channel) {
        self.channel = channel
    }

    func writeAndFlush<T>(_ any: T) -> EventLoopFuture<Void> {
        channel.writeAndFlush(any)
    }

    func close() -> EventLoopFuture<Void> {
        channel.close()
    }
}
