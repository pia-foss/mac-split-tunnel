import Foundation
import NetworkExtension
import NIO

final class IOFlowLibNIO : IOFlowLib {
    let eventLoopGroup: MultiThreadedEventLoopGroup
    let interfaceAddress: String
    let dictionary: IODictionary
    
    init(interfaceName: String) {
        self.interfaceAddress = getNetworkInterfaceIP(interfaceName: interfaceName)!
        // Trying with just 1 thread for now, since we dont want to use too many resources on the user's machines.
        // According to SwiftNIO docs it is better to use MultiThreadedEventLoopGroup
        // even in the case of just 1 thread
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.dictionary = IODictionaryNIO(label: "com.privateinternetaccess.splittunnel.poc.extension.systemextension.flowChannelMapQueue")
    }
    
    deinit {
        try! eventLoopGroup.syncShutdownGracefully()
    }

    func handleTCPFlowIO(_ flow: NEAppProxyTCPFlow) {
        let (endpointAddress, endpointPort) = getAddressAndPort(endpoint: flow.remoteEndpoint as! NWHostEndpoint)
        // Setting up the read event handler for the socket
        let channel = initTCPChannel(host: endpointAddress!, port: endpointPort!)
        log(.info, "\(flow.metaData.sourceAppSigningIdentifier) A new TCP socket has been created, bound and connected")
        // Linking this flow and channel, so that it is always possible to retrive one from the other
        dictionary.add(flow: flow, channel: channel)
        
        // Scheduling the first read on the flow.
        // The following ones will be scheduled in the socket write handler
        scheduleTCPFlowRead(flow)
        // We are "done", so this function can return.
        // From this point on:
        // - any new flow outbound traffic will trigger the flow read completion handler
        // - any new socket inboud traffic will trigger InboudTCPHandler.channelRead()
    }

    func handleUDPFlowIO(_ flow: NEAppProxyUDPFlow) {
        // Setting up the read event handler for the socket
        let channel = initUDPChannel()
        log(.info, "\(flow.metaData.sourceAppSigningIdentifier) A new UDP socket has been created and bound")
        // Linking this flow and channel, so that it is always possible to retrive one from the other
        dictionary.add(flow: flow, channel: channel)
        
        scheduleUDPFlowRead(flow)
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
                channel.pipeline.addHandler(InboundTCPHandler(dictionary: self.dictionary))
            }
        // TODO: Handle bind and connect failures
        bootstrap = try! bootstrap.bind(to: SocketAddress(ipAddress: interfaceAddress, port: 0))
        return try! bootstrap.connect(host: host, port: port).wait()
    }
    
    // this function creates, bind and connect a new TCP channel
    private func initUDPChannel() -> Channel {
        // Bootstrap is a easier way to create a Channel (SocketChannel in our use case)
        var bootstrap = DatagramBootstrap(group: eventLoopGroup)
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
                channel.pipeline.addHandler(InboundUDPHandler(dictionary: self.dictionary))
            }
        // TODO: Handle bind failures
        return try! bootstrap.bind(to: SocketAddress(ipAddress: interfaceAddress, port: 0)).wait()
    }
    
    private func scheduleTCPFlowRead(_ flow: NEAppProxyTCPFlow) {
        flow.readData { outboundData, flowError in
            // when new data is available to read from a flow,
            // and no errors occurred
            // we want to write that data to the corresponding socket
            if flowError == nil, let data = outboundData, !data.isEmpty {
                log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) TCP flow.readData() has read: \(data)")
                
                guard let channel = self.dictionary.getChannel(flow: flow) else {
                    log(.error, "\(flow.metaData.sourceAppSigningIdentifier) Could not get corresponding channel from the dictionary")
                    return
                    // TODO: Handle the error
                }
                let buffer = channel.allocator.buffer(bytes: data)
                channel.writeAndFlush(buffer).whenComplete { result in
                    switch result {
                    case .success:
                        log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) TCP data successfully sent through the socket")
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
    
    private func scheduleUDPFlowRead(_ flow: NEAppProxyUDPFlow) {
        flow.readDatagrams { outboundData, outboundEndpoints, flowError in
            if flowError == nil, let datas = outboundData, !datas.isEmpty, let endpoints = outboundEndpoints, !endpoints.isEmpty {
                log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) UDP flow.readDatagrams() has read: \(datas)")
                
                guard let channel = self.dictionary.getChannel(flow: flow) else {
                    log(.error, "\(flow.metaData.sourceAppSigningIdentifier) Could not get corresponding channel from the dictionary")
                    return
                    // TODO: Handle the error
                }
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
                            self.scheduleUDPFlowRead(flow)
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
final class InboundTCPHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer
    
    let dictionary: IODictionary
    
    init(dictionary: IODictionary) {
        self.dictionary = dictionary
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let input = self.unwrapInboundIn(data)
        guard let bytes = input.getBytes(at: 0, length: input.readableBytes) else {
            return
        }
        guard let flow = dictionary.getFlow(channel: context.channel) as? NEAppProxyTCPFlow else {
            log(.error, "Could not get corresponding TCP flow from the dictionary")
            return
            // TODO: Handle the error
        }
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

// In this class we handle receiving data on a UDP socket and
// writing that data to the flow
final class InboundUDPHandler: ChannelInboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias OutboundOut = ByteBuffer
    
    let dictionary: IODictionary
    
    init(dictionary: IODictionary) {
        self.dictionary = dictionary
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let input = self.unwrapInboundIn(data)
        guard let bytes = input.data.getBytes(at: 0, length: input.data.readableBytes) else {
            return
        }
        guard let flow = dictionary.getFlow(channel: context.channel) as? NEAppProxyUDPFlow else {
            log(.error, "Could not get corresponding UDP flow from the dictionary")
            return
            // TODO: Handle the error
        }
        let address = input.remoteAddress.ipAddress
        let port = input.remoteAddress.port
        let endpoint = NWHostEndpoint(hostname: address!, port: String(port!))
        log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) There is a new inbound UDP socket datagram from address: \(address!)")
        
        // new traffic is ready to be read on the socket
        // we want to write that data to the flow
        flow.writeDatagrams([Data(bytes)], sentBy: [endpoint]) { flowError in
            if flowError == nil {
                log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) a UDP datagram has been successfully written to the flow")
                // no op
                // the next time data is available to read on the socket
                // this function will be called again automatically by the event loop
            } else {
                log(.error, "\(flow.metaData.sourceAppSigningIdentifier) \(flowError!.localizedDescription) occurred when writing a UDP datagram to the flow")
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
