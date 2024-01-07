//
//  ProxySessionUDP.swift
//  SplitTunnelProxyExtension
//
//  Created by John Mair on 07/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NetworkExtension
import NIO

class ProxySessionUDP: ProxySession {
    let flow: NEAppProxyUDPFlow
    let sessionConfig: SessionConfig
    let id: IDGenerator.ID // Unique identifier for this session
    var channel: Channel!

    init(flow: NEAppProxyUDPFlow, sessionConfig: SessionConfig, id: IDGenerator.ID) {
        self.flow = flow
        self.sessionConfig = sessionConfig
        self.id = id
    }

    public func start() -> EventLoopFuture<Channel> {
        let channelFuture = initChannel(flow: flow)
        channelFuture.whenSuccess { channel in
            log(.debug, "id: \(self.id) \(self.flow.metaData.sourceAppSigningIdentifier) A new UDP socket has been initialized")
            self.channel = channel
            self.scheduleFlowRead(flow: self.flow, channel: self.channel)
        }
        channelFuture.whenFailure { error in
            log(.error, "id: \(self.id) Unable to establish UDP: \(error), dropping the flow.")
            TrafficManagerNIO.dropFlow(flow: self.flow)
        }

        return channelFuture
    }

    public func terminate() {
        log(.error, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) Terminating the session.")
        TrafficManagerNIO.terminateProxySession(flow: flow, channel: channel)
    }

    public func identifier() -> IDGenerator.ID { self.id }

    // this function creates and bind a new UDP channel
    private func initChannel(flow: NEAppProxyUDPFlow) -> EventLoopFuture<Channel> {
        log(.debug, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) creating and binding a new UDP socket")
        let bootstrap = DatagramBootstrap(group: sessionConfig.eventLoopGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(InboundHandlerUDP(flow: flow, id: self.id))
            }

        do {
            // This is the only call that can throw an exception
            let socketAddress = try SocketAddress(ipAddress: sessionConfig.interfaceAddress, port: 0)
            // Not calling connect() on a UDP socket.
            // Doing that will turn the socket into a "connected datagram socket".
            // That will prevent the application from exchanging data with multiple endpoints
            let channelFuture = bootstrap.bind(to: socketAddress)
            return channelFuture
        } catch {
            return sessionConfig.eventLoopGroup.next().makeFailedFuture(error)
        }
    }

    // schedule a new read on a UDP flow
    private func scheduleFlowRead(flow: NEAppProxyUDPFlow, channel: Channel) {
        flow.readDatagrams { outboundData, outboundEndpoints, flowError in
            if flowError == nil, let datas = outboundData, !datas.isEmpty, let endpoints = outboundEndpoints, !endpoints.isEmpty {
                log(.debug, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) UDP flow.readDatagrams() has read: \(datas)")

                var readIsScheduled = false
                for (data, endpoint) in zip(datas, endpoints) {
                    // Kill the proxy session if we can't create a datagram
                    guard let datagram = self.createDatagram(channel: channel, data: data, endpoint: endpoint) else {
                        self.terminate()
                        return
                    }

                    channel.writeAndFlush(datagram).whenComplete { result in
                        switch result {
                        case .success:
                            log(.debug, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) UDP datagram successfully sent through the socket")

                            // Only schedule another read if we haven't already done so
                            if !readIsScheduled {
                                self.scheduleFlowRead(flow: flow, channel: channel)
                                readIsScheduled = true
                            }
                        case .failure(let error):
                            log(.error, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) \(error) while sending a UDP datagram through the socket")
                            self.terminate()
                        }
                    }
                }
            } else {
                log(.error, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) \((flowError?.localizedDescription) ?? "Empty buffer") occurred during UDP flow.readDatagrams()")

                self.terminate()
            }
        }
        log(.debug, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) A new UDP flow readDatagrams() has been scheduled")
    }

    private func createDatagram(channel: Channel, data: Data, endpoint: NWEndpoint) -> AddressedEnvelope<ByteBuffer>? {
        let buffer = channel.allocator.buffer(bytes: data)
        let (endpointAddress, endpointPort) = getAddressAndPort(endpoint: endpoint as! NWHostEndpoint)
        do {
            let destination = try SocketAddress(ipAddress: endpointAddress!, port: endpointPort!)
            return AddressedEnvelope<ByteBuffer>(remoteAddress: destination, data: buffer)
        } catch {
            log(.error, "id: \(self.id) datagram creation failed")
            return nil
        }
    }
}

final class InboundHandlerUDP: ChannelInboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias OutboundOut = ByteBuffer

    let flow: NEAppProxyUDPFlow
    let id: IDGenerator.ID

    init(flow: NEAppProxyUDPFlow, id: IDGenerator.ID) {
        self.flow = flow
        self.id = id
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let input = self.unwrapInboundIn(data)
        guard let bytes = input.data.getBytes(at: 0, length: input.data.readableBytes) else {
            return
        }
        let address = input.remoteAddress.ipAddress
        let port = input.remoteAddress.port
        let endpoint = NWHostEndpoint(hostname: address!, port: String(port!))
        log(.debug, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) There is a new inbound UDP socket datagram from address: \(address!)")

        // new traffic is ready to be read on the socket
        // we want to write that data to the flow
        flow.writeDatagrams([Data(bytes)], sentBy: [endpoint]) { flowError in
            if flowError == nil {
                log(.debug, "id: \(self.id) \(self.flow.metaData.sourceAppSigningIdentifier) a UDP datagram has been successfully written to the flow")
                // no op
                // the next time data is available to read on the socket
                // this function will be called again automatically by the event loop
            } else {
                log(.error, "id: \(self.id) \(self.flow.metaData.sourceAppSigningIdentifier) \(flowError!.localizedDescription) occurred when writing a UDP datagram to the flow")
                self.terminate(context: context)
            }
        }
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        log(.error, "id: \(self.id) \(error) in InboundTCPHandler")
        terminate(context: context)
    }

    func terminate(context: ChannelHandlerContext) {
        log(.error, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) Terminating the session.")
        TrafficManagerNIO.terminateProxySession(flow: flow, context: context)
    }
}

