import Foundation
import NetworkExtension
import NIO

final class IOFlowLibNIO : IOFlowLib {
    let eventLoopGroup: MultiThreadedEventLoopGroup
    let interfaceAddress: String
    
    init(interfaceName: String) {
        self.interfaceAddress = getNetworkInterfaceIP(interfaceName: interfaceName)!
        // trying with just 1 thread for now, since we dont want to use too many resources on the user's machines.
        // SwiftNIO docs says it is still better to use MultiThreadedEventLoopGroup, even in the case of 1 thread used
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    deinit {
        try! eventLoopGroup.syncShutdownGracefully()
    }

    func handleTCPFlowIO(_ flow: NEAppProxyTCPFlow) {
        let (endpointAddress, endpointPort) = getAddressAndPort(endpoint: flow.remoteEndpoint as! NWHostEndpoint)
        createNewTCPChannel(host: endpointAddress!, port: endpointPort!)
    }

    func handleUDPFlowIO(_ flow: NEAppProxyUDPFlow) {
    }
    
    func createNewTCPChannel(host: String, port: Int) {
        // Bootstrap is a easier way to create a Channel (SocketChannel in our use case)
        var bootstrap = ClientBootstrap(group: eventLoopGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                // always instantiate the handler _within_ the closure as
                // it may be called multiple times (for example if the hostname
                // resolves to both IPv4 and IPv6 addresses, cf. Happy Eyeballs).
                //
                // add the handlers to the channel pipeline
                channel.pipeline.addHandlers([
                    InboudTCPHandler(),
                    OutboundTCPHandler(),
                ])
            }
        bootstrap = try! bootstrap.bind(to: SocketAddress(ipAddress: interfaceAddress, port: 0))
        try! bootstrap.connect(host: host, port: port).wait()
        log(.info, "A new TCP socket has been created, bound and connected")
    }
}

final class InboundTCPHandler: ChannelInboundHandler {

    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    func channelRead(
        context: ChannelHandlerContext,
        data: NIOAny
    ) {
        let input = self.unwrapInboundIn(data)
        guard
            let message = input.getString(at: 0, length: input.readableBytes)
        else {
            return
        }
        log(.debug, "there is new inbound TCP socket traffic")
        // do something with inbound data
    }

    func channelReadComplete(
        context: ChannelHandlerContext
    ) {
        context.flush()
    }

    func errorCaught(
        context: ChannelHandlerContext,
        error: Error
    ) {
        print(error)
        context.close(promise: nil)
    }
}

final class OutboundTCPHandler: ChannelOutboundHandler {
    typealias OutboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer

    func channelWrite(
        context: ChannelHandlerContext,
        data: NIOAny
    ) {
        log(.debug, "there is new outbound TCP socket traffic")
        // do something with outbound data
    }


    func channelWriteComplete(
        context: ChannelHandlerContext
    ) {
        context.flush()
    }

    func errorCaught(
        context: ChannelHandlerContext,
        error: Error
    ) {
        print(error)

        context.close(promise: nil)
    }
}
