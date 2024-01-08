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

    init(flow: NEAppProxyUDPFlow, sessionConfig: SessionConfig, id: IDGenerator.ID) {
        self.flow = flow
        self.sessionConfig = sessionConfig
        self.id = id
    }

    deinit {
        log(.debug, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) ProxySession closed. rxBytes=\(formatByteCount(rxBytes)) txBytes=\(formatByteCount(txBytes))")
    }

    private func formatByteCount(_ byteCount: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB] // Options are .useBytes, .useKB, .useMB, .useGB, etc.
        formatter.countStyle = .file  // Options are .file (1024 bytes = 1KB) or .memory (1000 bytes = 1KB)
        formatter.includesUnit = true // Whether to include the unit string (KB, MB, etc.)
        formatter.isAdaptive = true

        // Converting from UInt64 to Int64 - not ideal but not a problem in practice
        // as Int64 can represent values up to 9 exabytes
        return formatter.string(fromByteCount: Int64(byteCount))
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
        log(.debug, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) Creating and binding a new UDP socket")
        let bootstrap = DatagramBootstrap(group: sessionConfig.eventLoopGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                let inboundHandler = InboundHandlerUDP(flow: flow, id: self.id) { (byteCount: UInt64) in
                    self.rxBytes &+= byteCount
                }
                return channel.pipeline.addHandler(inboundHandler)
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
        //log(.debug, "id: \(self.id) \(flow.metaData.sourceAppSigningIdentifier) A new UDP flow readDatagrams() has been scheduled")
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
    let onBytesReceived: (UInt64) -> Void

    init(flow: NEAppProxyUDPFlow, id: IDGenerator.ID, onBytesReceived: @escaping (UInt64) -> Void) {
        self.flow = flow
        self.id = id
        self.onBytesReceived = onBytesReceived
    }

    deinit {
        log(.debug, "id: \(self.id) Destructor called for InboundHandlerTCP")
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let input = self.unwrapInboundIn(data)
        guard let bytes = input.data.getBytes(at: 0, length: input.data.readableBytes) else {
            return
        }
        let address = input.remoteAddress.ipAddress
        let port = input.remoteAddress.port
        let endpoint = NWHostEndpoint(hostname: address!, port: String(port!))

        // new traffic is ready to be read on the socket
        // we want to write that data to the flow
        flow.writeDatagrams([Data(bytes)], sentBy: [endpoint]) { flowError in
            if flowError == nil {
                self.onBytesReceived(UInt64(bytes.count))
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

