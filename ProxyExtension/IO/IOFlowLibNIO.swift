import Foundation
import NetworkExtension
import NIO

// TODO: Change this to an hash map / list
// instead of a global variable, to improve testability, this could be:
// - a singleton class holding the list, we inject in IOFlowLibNIO and in the handlers
// - an even better idea?
var myFlow: NEAppProxyFlow?
var myChannel: Channel?

// TODO: Make this add a new pair to an hash map / list
// so that it is always possible to get one from the other, possibly in O(1)
func linkFlowAndChannel(_ flow: NEAppProxyFlow, _ channel: Channel) {
    myFlow = flow
    myChannel = channel
}

// this is not used atm
func getFlow(channel: Channel) -> NEAppProxyFlow {
    return myFlow!
}

func getChannel(flow: NEAppProxyFlow) -> Channel {
    return myChannel!
}



final class IOFlowLibNIO : IOFlowLib {
    let eventLoopGroup: MultiThreadedEventLoopGroup
    let interfaceAddress: String
    
    init(interfaceName: String) {
        self.interfaceAddress = getNetworkInterfaceIP(interfaceName: interfaceName)!
        // trying with just 1 thread for now, since we dont want to use too many resources on the user's machines.
        // SwiftNIO docs says it is still better to use MultiThreadedEventLoopGroup, even in the case of just 1 thread
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    deinit {
        try! eventLoopGroup.syncShutdownGracefully()
    }

    func handleTCPFlowIO(_ flow: NEAppProxyTCPFlow) {
        let (endpointAddress, endpointPort) = getAddressAndPort(endpoint: flow.remoteEndpoint as! NWHostEndpoint)
        // Setting up handlers for read and write events on the local socket
        let channel = initTCPChannel(host: endpointAddress!, port: endpointPort!)
        log(.info, "\(flow.metaData.sourceAppSigningIdentifier) A new TCP socket has been created, bound and connected")
        // Linking this flow and channel, so that it is always possible to retrive one from the other
        linkFlowAndChannel(flow, channel)
        
        // Scheduling the first read on the flow.
        // Following ones will be called in the socket write handler
        scheduleTCPFlowRead(flow)
        // we are "done", so this function can return.
        // From this point on:
        // - any new flow outbound traffic will trigger the flow read completion handler
        // - any new socket inboud traffic will trigger InboudTCPHandler.channelRead()
    }

    func handleUDPFlowIO(_ flow: NEAppProxyUDPFlow) {
    }
    
    // this function creates, bind and connect a new TCP channel
    private func initTCPChannel(host: String, port: Int) -> Channel {
        // Bootstrap is a easier way to create a Channel (SocketChannel in our use case)
        var bootstrap = ClientBootstrap(group: eventLoopGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                // always instantiate the handler _within_ the closure as
                // it may be called multiple times (for example if the hostname
                // resolves to both IPv4 and IPv6 addresses, cf. Happy Eyeballs).
                //
                // We add only the inbound handler to the channel pipeline.
                // We don't add a OutboundTCPHandler because SwiftNIO doesn't use it
                // when using channel.writeAndFlush() ¯\_(ツ)_/¯
                channel.pipeline.addHandler(InboudTCPHandler())
            }
        bootstrap = try! bootstrap.bind(to: SocketAddress(ipAddress: interfaceAddress, port: 0))
        return try! bootstrap.connect(host: host, port: port).wait()
    }
    
    private func scheduleTCPFlowRead(_ flow: NEAppProxyTCPFlow) {
        flow.readData { outboundData, flowError in
            // when new data is available to read from a flow,
            // and no errors occurred
            // we want to write that data to the corresponding socket
            if flowError == nil, let data = outboundData, !data.isEmpty {
                log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) TCP flow.readData() has read: \(data)")
                
                let channel = getChannel(flow: flow)
                let buffer = channel.allocator.buffer(bytes: data)
                getChannel(flow: flow).writeAndFlush(buffer).whenComplete { result in
                    switch result {
                    case .success:
                        log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) TCP data sent successfully through the socket")
                        // since everything worked as expected, we schedule another read on the flow
                        self.scheduleTCPFlowRead(flow)
                    case .failure(let error):
                        log(.error, "\(flow.metaData.sourceAppSigningIdentifier) \(error) while sending TCP data through the socket")
                        // TODO: Close flow and channel if an error occurred during socket write
                    }
                }
            } else {
                log(.error, "\(flow.metaData.sourceAppSigningIdentifier) \((flowError?.localizedDescription) ?? "Empty buffer") occurred during TCP flow.readData()")
                // TODO: Close flow and channel if an error occurred during flow read
            }
        }
        log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) A new TCP flow readData() has been scheduled")
    }
}

// in this class we handle receiving data on the socket and
// writing that data to the flow
final class InboundTCPHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let input = self.unwrapInboundIn(data)
        guard let bytes = input.getBytes(at: 0, length: input.readableBytes) else {
            return
        }
        let flow = getFlow(channel: context.channel) as! NEAppProxyTCPFlow
        log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) There is new inbound TCP socket data")
        
        // new traffic is ready to be read on the socket
        // we want to write that data to the flow
        flow.write(Data(bytes)) { flowError in
            if flowError == nil {
                log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) TCP data has been successfully written to the flow")
                // no op
                // the next time data is available to read on the socket
                // this function will be called again automatically by the event loop
            } else {
                log(.error, "\(flow.metaData.sourceAppSigningIdentifier) \(flowError!.localizedDescription) occurred when writing TCP data to the flow")
                // TODO: Close flow and channel if an error occurred during flow write
            }
        }
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        log(.error, "\(error) in InboundTCPHandler")
        context.close(promise: nil)
        // TODO: Close flow and channel if an error occurred during socket read
    }
}
