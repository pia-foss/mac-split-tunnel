import Foundation
import NetworkExtension
import NIO

final class IOFlowLibNIO : IOFlowLib {
    let eventLoopGroup: MultiThreadedEventLoopGroup
    let interfaceAddress: String
    
    init(interfaceName: String) {
        self.interfaceAddress = getNetworkInterfaceIP(interfaceName: interfaceName)!
        // Trying with just 1 thread for now, since we dont want to use too many resources on the user's machines.
        // According to SwiftNIO docs it is better to use MultiThreadedEventLoopGroup
        // even in the case of just 1 thread
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    deinit {
        try! eventLoopGroup.syncShutdownGracefully()
    }

    func handleFlowIO(_ flow: NEAppProxyFlow) {
        if let tcpFlow = flow as? NEAppProxyTCPFlow {
            let (endpointAddress, endpointPort) = getAddressAndPort(endpoint: tcpFlow.remoteEndpoint as! NWHostEndpoint)
            let channel = initChannel(flow: tcpFlow, host: endpointAddress!, port: endpointPort!)
            log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) A new TCP socket has been created, bound and connected")
            scheduleFlowRead(flow: tcpFlow, channel: channel)
        } else if let udpFlow = flow as? NEAppProxyUDPFlow {
            let channel = initChannel(flow: udpFlow)
            log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) A new UDP socket has been created and bound")
            scheduleFlowRead(flow: udpFlow, channel: channel)
        }
        
        // The first read has been scheduled on the flow.
        // The following ones will be scheduled in the socket write handler
        //
        // From this point on:
        // - any new flow outbound traffic will trigger the flow read completion handler
        // - any new socket inboud traffic will trigger InboudHandler.channelRead()
    }
    
    // this function creates, bind and connect a new TCP channel
    private func initChannel(flow: NEAppProxyTCPFlow, host: String, port: Int) -> Channel {
        var bootstrap = ClientBootstrap(group: eventLoopGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                // We add only the inbound handler to the channel pipeline.
                // We don't add an outbound handler because SwiftNIO doesn't use it
                // when using channel.writeAndFlush() ¯\_(ツ)_/¯
                channel.pipeline.addHandler(InboundHandlerTCP(flow: flow))
            }
        // TODO: Handle bind and connect failures
        bootstrap = try! bootstrap.bind(to: SocketAddress(ipAddress: interfaceAddress, port: 0))
        return try! bootstrap.connect(host: host, port: port).wait()
    }
    
    // this function creates and bind a new UDP channel
    private func initChannel(flow: NEAppProxyUDPFlow) -> Channel {
        var bootstrap = DatagramBootstrap(group: eventLoopGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(InboundHandlerUDP(flow: flow))
            }
        // TODO: Handle bind failures
        return try! bootstrap.bind(to: SocketAddress(ipAddress: interfaceAddress, port: 0)).wait()
        // Not calling connect() on a UDP socket.
        // Doing that will turn the socket into a "connected datagram socket".
        // That will prevent the application from exchanging data with multiple endpoints
    }
    
    // schedule a new read on a TCP flow
    private func scheduleFlowRead(flow: NEAppProxyTCPFlow, channel: Channel) {
        flow.readData { outboundData, flowError in
            // when new data is available to read from a flow,
            // and no errors occurred
            // we want to write that data to the corresponding socket
            if flowError == nil, let data = outboundData, !data.isEmpty {
                log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) TCP flow.readData() has read: \(data)")
                
                let buffer = channel.allocator.buffer(bytes: data)
                channel.writeAndFlush(buffer).whenComplete { result in
                    switch result {
                    case .success:
                        log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) TCP data successfully sent through the socket")
                        // since everything worked as expected, we schedule another read on the flow
                        self.scheduleFlowRead(flow: flow, channel: channel)
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
    
    // schedule a new read on a UDP flow
    private func scheduleFlowRead(flow: NEAppProxyUDPFlow, channel: Channel) {
        flow.readDatagrams { outboundData, outboundEndpoints, flowError in
            if flowError == nil, let datas = outboundData, !datas.isEmpty, let endpoints = outboundEndpoints, !endpoints.isEmpty {
                log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) UDP flow.readDatagrams() has read: \(datas)")
                
                for (data, endpoint) in zip(datas, endpoints) {
                    let datagram = self.createDatagram(channel: channel, data: data, endpoint: endpoint)
                    channel.writeAndFlush(datagram!).whenComplete { result in
                        switch result {
                        case .success:
                            log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) UDP datagram successfully sent through the socket")
                            // since everything worked as expected, we schedule another read on the flow
                            //
                            // for UDP we might get more than 1 data buffer:
                            // right now, if the array contains more than one element
                            // and write is successful we will schedule more than 1 read.
                            // This raises an error.
                            // TODO: Check if the error make the flow no longer readable/writable, or if it  can be ignored
                            // We could extend either the flow or the channel and add an atomic
                            // bool that says if a read has already been scheduled.
                            // It would need to be set to false, after we successfully complete a read
                            self.scheduleFlowRead(flow: flow, channel: channel)
                        case .failure(let error):
                            log(.error, "\(flow.metaData.sourceAppSigningIdentifier) \(error) while sending a UDP datagram through the socket")
                            // TODO: Close flow and channel if an error occurred during socket write
                        }
                    }
                }
            } else {
                log(.error, "\(flow.metaData.sourceAppSigningIdentifier) \((flowError?.localizedDescription) ?? "Empty buffer") occurred during UDP flow.readDatagrams()")
                // TODO: Close flow and channel if an error occurred during flow read
            }
        }
        log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) A new UDP flow readDatagrams() has been scheduled")
    }
    
    private func createDatagram (channel: Channel, data: Data, endpoint: NWEndpoint) -> AddressedEnvelope<ByteBuffer>? {
        let buffer = channel.allocator.buffer(bytes: data)
        let (endpointAddress, endpointPort) = getAddressAndPort(endpoint: endpoint as! NWHostEndpoint)
        do {
            let destination = try SocketAddress(ipAddress: endpointAddress!, port: endpointPort!)
            return AddressedEnvelope<ByteBuffer>(remoteAddress: destination, data: buffer)
        } catch {
            log(.error, "datagram creation failed")
            return nil
        }
    }
}

// In this class we handle receiving data on a TCP socket and
// writing that data to the flow
final class InboundHandlerTCP: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer
    
    let flow: NEAppProxyTCPFlow
    
    init(flow: NEAppProxyTCPFlow) {
        self.flow = flow
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let input = self.unwrapInboundIn(data)
        guard let bytes = input.getBytes(at: 0, length: input.readableBytes) else {
            return
        }
        log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) There is new inbound TCP socket data")
        
        // new traffic is ready to be read on the socket
        // we want to write that data to the flow
        flow.write(Data(bytes)) { flowError in
            if flowError == nil {
                log(.debug, "\(self.flow.metaData.sourceAppSigningIdentifier) TCP data has been successfully written to the flow")
                // no op
                // the next time data is available to read on the socket
                // this function will be called again automatically by the event loop
            } else {
                log(.error, "\(self.flow.metaData.sourceAppSigningIdentifier) \(flowError!.localizedDescription) occurred when writing TCP data to the flow")
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

// In this class we handle receiving data on a UDP socket and
// writing that data to the flow
final class InboundHandlerUDP: ChannelInboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias OutboundOut = ByteBuffer
    
    let flow: NEAppProxyUDPFlow
    
    init(flow: NEAppProxyUDPFlow) {
        self.flow = flow
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let input = self.unwrapInboundIn(data)
        guard let bytes = input.data.getBytes(at: 0, length: input.data.readableBytes) else {
            return
        }
        let address = input.remoteAddress.ipAddress
        let port = input.remoteAddress.port
        let endpoint = NWHostEndpoint(hostname: address!, port: String(port!))
        log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) There is a new inbound UDP socket datagram from address: \(address!)")
        
        // new traffic is ready to be read on the socket
        // we want to write that data to the flow
        flow.writeDatagrams([Data(bytes)], sentBy: [endpoint]) { flowError in
            if flowError == nil {
                log(.debug, "\(self.flow.metaData.sourceAppSigningIdentifier) a UDP datagram has been successfully written to the flow")
                // no op
                // the next time data is available to read on the socket
                // this function will be called again automatically by the event loop
            } else {
                log(.error, "\(self.flow.metaData.sourceAppSigningIdentifier) \(flowError!.localizedDescription) occurred when writing a UDP datagram to the flow")
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
