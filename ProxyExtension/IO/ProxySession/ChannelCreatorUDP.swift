import NIO
import NetworkExtension

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

            var localEndpoint: String
            // Used by IPv6
            if let endpoint = flow.localEndpoint as? NWHostEndpoint {
                localEndpoint = endpoint.hostname
            } else {
                log(.warning, "id: \(self.id) Could not convert flow.localEndpoint to NWHostEndpoint, defaulting to :: for ipv6 flows")
                localEndpoint = "::"
            }

            // For IPv4 flows we want to bind to the "bind ip" but for IPv6 flows
            // we want to bind to the IPv6 localEndpoint - UDP sockets (even clients) must
            // be explicitly bound.
            let bindIpAddress = flow.isIpv4() ? config.bindIp : localEndpoint

            // This is the only call that can throw an exception
            // We don't specify the port so the OS assigns one.
            let socketAddress = try SocketAddress(ipAddress: bindIpAddress, port: 0)

            let channelFuture = bootstrap.bind(to: socketAddress)

            log(.debug, "id: \(self.id) \(flow.sourceAppSigningIdentifier) " +
                "Creating and binding a new UDP socket with bindIp: \(bindIpAddress) and localEndpoint: \(flow.localEndpoint?.description ?? "N/A")")

            return channelFuture
        } catch {
            return config.eventLoopGroup.next().makeFailedFuture(error)
        }
    }
}
