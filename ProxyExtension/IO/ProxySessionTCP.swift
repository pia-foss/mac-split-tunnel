//
//  ProxySession.swift
//  SplitTunnelProxyExtension
//
//  Created by John Mair on 07/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NetworkExtension
import NIO

class ProxySessionTCP: ProxySession {
    let flow: NEAppProxyTCPFlow
    let sessionConfig: SessionConfig
    let id: IDGenerator.ID // Unique identifier for this session
    var channel: Channel!

    // Number of bytes transmitted and received
    var _txBytes: UInt64 = 0
    var _rxBytes: UInt64 = 0

    var txBytes: UInt64 {
        get { return _txBytes }
        set(newTxBytes) { _txBytes = newTxBytes }
    }

    var rxBytes: UInt64 {
        get { return _rxBytes }
        set(newTxBytes) { _rxBytes = newTxBytes }
    }

    init(flow: NEAppProxyTCPFlow, sessionConfig: SessionConfig, id: IDGenerator.ID) {
        self.flow = flow
        self.sessionConfig = sessionConfig
        self.id = id
    }

    deinit {
        log(.debug, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) ProxySession closed. rxBytes=\(formatByteCount(rxBytes)) txBytes=\(formatByteCount(txBytes))")
    }

    public func start() -> EventLoopFuture<Channel> {
        let channelFuture = initChannel(flow: flow)
        channelFuture.whenSuccess { channel in
            self.channel = channel
            self.scheduleFlowRead(flow: self.flow, channel: self.channel)
        }
        channelFuture.whenFailure { error in
            log(.error, "id: \(self.id) Unable to TCP connect: \(error), dropping the flow.")
            TrafficManagerNIO.dropFlow(flow: self.flow)
        }

        return channelFuture
    }

    public func terminate() {
        TrafficManagerNIO.terminateProxySession(flow: flow, channel: channel)
    }

    public func identifier() -> IDGenerator.ID { self.id }

    private func initChannel(flow: NEAppProxyTCPFlow) -> EventLoopFuture<Channel> {
        // Assuming interfaceAddress is already defined
        let (endpointAddress, endpointPort) = getAddressAndPort(endpoint: flow.remoteEndpoint as! NWHostEndpoint)
        log(.debug, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) Creating, binding and connecting a new TCP socket - remote address: \(endpointAddress!) remote port: \(endpointPort!)")

        let bootstrap = ClientBootstrap(group: sessionConfig.eventLoopGroup)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                let inboundHandler = InboundHandlerTCP(flow: flow, id: self.id) { (byteCount: UInt64) in
                    self.rxBytes &+= byteCount
                }
                return channel.pipeline.addHandler(inboundHandler)
            }

        // Bind to a local address and then connect
        do {
            // This is the only call that can throw an exception
            let socketAddress = try SocketAddress(ipAddress: sessionConfig.interfaceAddress, port: 0)
            let channelFuture = bootstrap.bind(to: socketAddress)
                .connect(host: endpointAddress!, port: endpointPort!)

            return channelFuture
        } catch {
            return sessionConfig.eventLoopGroup.next().makeFailedFuture(error)
        }
    }

    // schedule a new read on a TCP flow
    private func scheduleFlowRead(flow: NEAppProxyTCPFlow, channel: Channel) {
        flow.readData { outboundData, flowError in
            // when new data is available to read from a flow,
            // and no errors occurred
            // we want to write that data to the corresponding socket
            if flowError == nil, let data = outboundData, !data.isEmpty {
                let buffer = channel.allocator.buffer(bytes: data)
                channel.writeAndFlush(buffer).whenComplete { result in
                    switch result {
                    case .success:
                        self.txBytes &+= UInt64(data.count)
                        // since everything worked as expected, we schedule another read on the flow
                        self.scheduleFlowRead(flow: flow, channel: channel)
                    case .failure(let error):
                        log(.error, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) \(error) while sending TCP data through the socket")
                        self.terminate()
                    }
                }
            } else {
                log(.error, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) \((flowError?.localizedDescription) ?? "Empty buffer") occurred during TCP flow.readData()")
                self.terminate()
            }
        }
    }
}

// In this class we handle receiving data on a TCP socket and
// writing that data to the flow
final class InboundHandlerTCP: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    let flow: NEAppProxyTCPFlow
    let id: IDGenerator.ID
    let onBytesReceived: (UInt64) -> Void

    init(flow: NEAppProxyTCPFlow, id: IDGenerator.ID, onBytesReceived: @escaping (UInt64) -> Void) {
        self.flow = flow
        self.id = id
        self.onBytesReceived = onBytesReceived
    }

    deinit {
        log(.debug, "id: \(self.id) Destructor called for InboundHandlerTCP")
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let input = self.unwrapInboundIn(data)
        guard let bytes = input.getBytes(at: 0, length: input.readableBytes) else {
            return
        }

        // new traffic is ready to be read on the socket
        // we want to write that data to the flow
        flow.write(Data(bytes)) { flowError in
            if flowError == nil {
                self.onBytesReceived(UInt64(bytes.count))

                // no op
                // the next time data is available to read on the socket
                // this function will be called again automatically by the event loop
            } else {
                log(.error, "id: \(self.id) \(self.flow.metaData.sourceAppSigningIdentifier) \(flowError!.localizedDescription) occurred when writing TCP data to the flow")
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
        log(.info, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) Terminating the session.")
        TrafficManagerNIO.terminateProxySession(flow: flow, context: context)
    }
}
