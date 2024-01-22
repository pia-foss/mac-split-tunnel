import Foundation
import NIO
import NetworkExtension

// Create a TCP channel and set up the inbound handler
final class ChannelCreatorTCP {
    let id: IDGenerator.ID
    let flow: FlowTCP
    let config: SessionConfig

    init(id: IDGenerator.ID, flow: FlowTCP, config: SessionConfig) {
        self.id = id
        self.flow = flow
        self.config = config
    }

    public func create(_ onBytesReceived: @escaping (UInt64) -> Void) 
        -> EventLoopFuture<Channel> {
        guard let endpoint = flow.remoteEndpoint as? NWHostEndpoint else {
            return makeFailedFuture(
                ProxySessionError.BadEndpoint("flow.remoteEndpoint is not an NWHostEndpoint"))
        }

        log(.debug, "id: \(self.id) \(flow.sourceAppSigningIdentifier) " + 
            "Creating, binding and connecting a new TCP socket - endpoint: \(endpoint)")

        let bootstrap = ClientBootstrap(group: config.eventLoopGroup)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                let inboundHandler = InboundHandlerTCP(flow: self.flow, id: self.id, 
                                                       onBytesReceived: onBytesReceived)
                return channel.pipeline.addHandler(inboundHandler)
            }

        return bindSourceAddressAndConnect(bootstrap, endpoint: endpoint)
    }

    private func bindSourceAddressAndConnect(_ bootstrap: ClientBootstrap, endpoint: NWHostEndpoint) 
        -> EventLoopFuture<Channel> {
        do {
            let (endpointAddress, endpointPort) = getAddressAndPort(endpoint: endpoint)
            // Return a friendly error on IPv6 addresses
            // TODO: Properly support IPv6 for the beta
            if (endpointAddress ?? "").contains(":") {
                return config.eventLoopGroup.next().makeFailedFuture(
                    ProxySessionError.IPv6("IPv6 is not yet supported"))
            }

            // This is the only call that can throw an exception
            let socketAddress = try SocketAddress(ipAddress: config.interfaceAddress, port: 0)
            let channelFuture = bootstrap.bind(to: socketAddress)
                .connect(host: endpointAddress!, port: endpointPort!)

            return channelFuture
        } catch {
            return makeFailedFuture(error)
        }
    }

    private func makeFailedFuture(_ error: Error) -> EventLoopFuture<Channel> {
        config.eventLoopGroup.next().makeFailedFuture(error)
    }
}
