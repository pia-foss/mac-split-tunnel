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
            "Creating, binding and connecting a new TCP socket - endpoint: \(endpoint) with bindIp: \(config.bindIp)")

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

            // If we have an IPv4 socket - bind, otherwise (IPv6) skip the bind
            if flow.isIpv4() {
                let socketAddress = try SocketAddress(ipAddress: config.bindIp, port: 0)
                _ = bootstrap.bind(to: socketAddress)
            }

            let channelFuture = bootstrap.connect(host: endpoint.hostname, port: Int(endpoint.port)!)
            return channelFuture

        } catch {
            return makeFailedFuture(error)
        }
    }

    private func makeFailedFuture(_ error: Error) -> EventLoopFuture<Channel> {
        config.eventLoopGroup.next().makeFailedFuture(error)
    }
}
