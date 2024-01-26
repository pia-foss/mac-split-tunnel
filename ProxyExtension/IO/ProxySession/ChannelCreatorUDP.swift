import NIO

// Create a UDP channel and set up the inbound handler
final class ChannelCreatorUDP {
    let id: IDGenerator.ID
    let flow: FlowUDP
    let config: SessionConfig

    init(id: IDGenerator.ID, flow: FlowUDP, config: SessionConfig) {
        self.id = id
        self.flow = flow
        self.config = config
    }

    public func create(_ onBytesReceived: @escaping (UInt64) -> Void) 
        -> EventLoopFuture<Channel> {
        log(.debug, "id: \(self.id) \(flow.sourceAppSigningIdentifier) " +
            "Creating and binding a new UDP socket")
        let bootstrap = DatagramBootstrap(group: config.eventLoopGroup)
            .channelInitializer { channel in
                let inboundHandler = InboundHandlerUDP(flow: self.flow, id: self.id, 
                                                       onBytesReceived: onBytesReceived)
                return channel.pipeline.addHandler(inboundHandler)
            }

        return bindSourceAddress(bootstrap)
    }

    private func bindSourceAddress(_ bootstrap: DatagramBootstrap) 
        -> EventLoopFuture<Channel> {
        do {
            // This is the only call that can throw an exception
            let socketAddress = try SocketAddress(ipAddress: config.bindIp, port: 0)
            // Not calling connect() on a UDP socket.
            // Doing that will turn the socket into a "connected datagram socket".
            // That will prevent the application from exchanging data with multiple endpoints
            let channelFuture = bootstrap.bind(to: socketAddress)
            return channelFuture
        } catch {
            return config.eventLoopGroup.next().makeFailedFuture(error)
        }
    }
}
