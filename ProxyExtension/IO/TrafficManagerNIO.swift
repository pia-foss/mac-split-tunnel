import Foundation
import NetworkExtension
import NIO

final class TrafficManagerNIO : TrafficManager {
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

    // Drop a flow by closing it
    // We use a class method so we can call it using `Self`.
    // We also call this method from outside this class.
    class func dropFlow(appFlow: NEAppProxyFlow) -> Void {
        let error = NSError(domain: "com.privateinternetaccess.vpn", code: 100, userInfo: nil)
        appFlow.closeReadWithError(error)
        appFlow.closeWriteWithError(error)
    }

    class func terminateProxySession(appFlow: NEAppProxyFlow, channel: Channel) -> Void {
        dropFlow(appFlow: appFlow)
        channel.close().whenFailure { error in
            // Not much we can do here other than trace it
            log(.error, "Failed to close the channel: \(error)")
        }
    }

    class func terminateProxySession(appFlow: NEAppProxyFlow, context: ChannelHandlerContext) -> Void {
        dropFlow(appFlow: appFlow)
        context.close().whenFailure { error in
            // Not much we can do here other than trace it
            log(.error, "Failed to close the channel: \(error)")
        }
    }

    func handleFlowIO(_ flow: NEAppProxyFlow) {
        if let tcpFlow = flow as? NEAppProxyTCPFlow {
            let channelFuture = initChannel(flow: tcpFlow)
            channelFuture.whenSuccess { channel in
                log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) A new TCP socket has been initialized")
                self.scheduleFlowRead(flow: tcpFlow, channel: channel)
            }
            channelFuture.whenFailure { error in
                log(.error, "Unable to TCP connect: \(error), dropping the flow.")
                Self.dropFlow(appFlow: tcpFlow)
            }
        } else if let udpFlow = flow as? NEAppProxyUDPFlow {
            let channelFuture = initChannel(flow: udpFlow)
            channelFuture.whenSuccess { channel in
                log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) A new UDP socket has been initialized")
                self.scheduleFlowRead(flow: udpFlow, channel: channel)
            }
            channelFuture.whenFailure { error in
                log(.error, "Unable to establish UDP: \(error), dropping the flow.")
                Self.dropFlow(appFlow: udpFlow)
            }
        }
        // The first read has been scheduled on the flow.
        // The following ones will be scheduled in the socket write handler
        //
        // From this point on:
        // - any new flow outbound traffic will trigger the flow read completion handler
        // - any new socket inboud traffic will trigger InboudHandler.channelRead()
    }
    
    // this function creates, binds and connects a new TCP channel
    private func initChannel(flow: NEAppProxyTCPFlow) -> EventLoopFuture<Channel> {
        log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) creating, binding and connecting a new TCP socket")
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(InboundHandlerTCP(flow: flow))
            }

        // Assuming interfaceAddress is already defined
        let (endpointAddress, endpointPort) = getAddressAndPort(endpoint: flow.remoteEndpoint as! NWHostEndpoint)

        // Bind to a local address and then connect
        do {
            // This is the only call that can throw an exception
            let socketAddress = try SocketAddress(ipAddress: interfaceAddress, port: 0)
            let channelFuture = bootstrap.bind(to: socketAddress)
                .connect(host: endpointAddress!, port: endpointPort!)

            return channelFuture
        } catch {
            return eventLoopGroup.next().makeFailedFuture(error)
        }
    }

    // this function creates and bind a new UDP channel
    private func initChannel(flow: NEAppProxyUDPFlow) -> EventLoopFuture<Channel> {
        log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) creating and binding a new UDP socket")
        let bootstrap = DatagramBootstrap(group: eventLoopGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(InboundHandlerUDP(flow: flow))
            }

        do {
            // This is the only call that can throw an exception
            let socketAddress = try SocketAddress(ipAddress: interfaceAddress, port: 0)
            // Not calling connect() on a UDP socket.
            // Doing that will turn the socket into a "connected datagram socket".
            // That will prevent the application from exchanging data with multiple endpoints
            let channelFuture = bootstrap.bind(to: socketAddress)
            return channelFuture
        } catch {
            return eventLoopGroup.next().makeFailedFuture(error)
        }
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
                        Self.terminateProxySession(appFlow: flow, channel: channel)
                    }
                }
            } else {
                log(.error, "\(flow.metaData.sourceAppSigningIdentifier) \((flowError?.localizedDescription) ?? "Empty buffer") occurred during TCP flow.readData()")
                Self.terminateProxySession(appFlow: flow, channel: channel)
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
                    // Kill the proxy session if we can't create a datagram
                    guard let datagram = self.createDatagram(channel: channel, data: data, endpoint: endpoint) else {
                        Self.terminateProxySession(appFlow: flow, channel: channel)
                        return
                    }

                    channel.writeAndFlush(datagram).whenComplete { result in
                        switch result {
                        case .success:
                            log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) UDP datagram successfully sent through the socket")
                            // since everything worked as expected, we schedule another read on the flow
                            //
                            // compared to TCP, for a UDP flow we get an array of [Data].
                            // If the array contains more than one element it is possible that we will
                            // try to schedule multiple reads.
                            // Scheduling a read, if one is already scheduled, raises an error:
                            // "A read operation is already pending".
                            // The error appears to be harmless though:
                            // flow.readDatagrams() will just return immediately and flow functionality
                            // will remain the same
                            self.scheduleFlowRead(flow: flow, channel: channel)
                        case .failure(let error):
                            log(.error, "\(flow.metaData.sourceAppSigningIdentifier) \(error) while sending a UDP datagram through the socket")
                            Self.terminateProxySession(appFlow: flow, channel: channel)
                        }
                    }
                }
            } else {
                log(.error, "\(flow.metaData.sourceAppSigningIdentifier) \((flowError?.localizedDescription) ?? "Empty buffer") occurred during UDP flow.readDatagrams()")

                // TODO: Make an exception for "A read operation is already pending" - do not terminate the session
                Self.terminateProxySession(appFlow: flow, channel: channel)
            }
        }
        log(.debug, "\(flow.metaData.sourceAppSigningIdentifier) A new UDP flow readDatagrams() has been scheduled")
    }
    
    private func createDatagram(channel: Channel, data: Data, endpoint: NWEndpoint) -> AddressedEnvelope<ByteBuffer>? {
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
                TrafficManagerNIO.terminateProxySession(appFlow: self.flow, context: context)
            }
        }
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        log(.error, "\(error) in InboundTCPHandler")
        TrafficManagerNIO.terminateProxySession(appFlow: self.flow, context: context)
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
                TrafficManagerNIO.terminateProxySession(appFlow: self.flow, context: context)
            }
        }
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        log(.error, "\(error) in InboundTCPHandler")
        TrafficManagerNIO.terminateProxySession(appFlow: self.flow, context: context)
    }
}
