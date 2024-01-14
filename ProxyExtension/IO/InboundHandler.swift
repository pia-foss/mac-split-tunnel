//
//  InboundHandler.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 14/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NIO

protocol InboundHandler: ChannelInboundHandler {
    var id: IDGenerator.ID { get }
}

// Don't need to specify the methods below as part of the protocol
// When you provide a default implementation for a method in a protocol extension, it's
// not mandatory for the conforming types to implement that method. The default
// implementation will be used unless the conforming type provides its own implementation.
extension InboundHandler {
    func terminate(channel: Channel) {
        if channel.isActive {
            let closeFuture = channel.close()
            closeFuture.whenSuccess {
                log(.info, "id: \(self.id) Successfully shutdown channel")
            }
            closeFuture.whenFailure { error in
                // Not much we can do here other than trace it
                log(.error, "Failed to close the channel: \(error)")
            }
        }
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        log(.error, "id: \(self.id) \(error) in InboundTCPHandler")
        terminate(channel: context.channel)
    }
}
