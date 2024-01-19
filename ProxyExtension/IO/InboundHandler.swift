import Foundation
import NIO

// Base protocol for our NIO inbound handlers (TCP, UDP)
protocol InboundHandler: ChannelInboundHandler {
    // Uniquely identifies a proxy session
    var id: IDGenerator.ID { get }
}

// Don't need to specify the methods below as part of the protocol
// When you provide a default implementation for a method in a protocol extension, it's
// not mandatory for the conforming types to implement that method. The default
// implementation will be used unless the conforming type provides its own implementation.
extension InboundHandler {
    // Used by an InboundHandler to close the connection
    func terminate(channel: Channel) {
        if channel.isActive {
            // Kill the channel
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
        log(.error, "id: \(self.id) \(error) in InboundHandler")
        terminate(channel: context.channel)
    }
}
