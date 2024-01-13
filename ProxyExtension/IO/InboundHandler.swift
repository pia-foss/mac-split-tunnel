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
    func terminate(channel: Channel)
    func channelReadComplete(context: ChannelHandlerContext)
    func errorCaught(context: ChannelHandlerContext, error: Error)
}

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
