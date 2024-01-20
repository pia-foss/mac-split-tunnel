//
//  InboundHandlerUDP.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 20/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NIO
import NetworkExtension

final class InboundHandlerUDP: InboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias OutboundOut = ByteBuffer

    let flow: FlowUDP
    let id: IDGenerator.ID
    let onBytesReceived: (UInt64) -> Void

    init(flow: FlowUDP, id: IDGenerator.ID, onBytesReceived: @escaping (UInt64) -> Void) {
        self.flow = flow
        self.id = id
        self.onBytesReceived = onBytesReceived
    }

    deinit {
        log(.debug, "id: \(self.id) Destructor called for InboundHandlerUDP")
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
                log(.error, "id: \(self.id) \(self.flow.sourceAppSigningIdentifier) \(flowError!.localizedDescription) occurred when writing a UDP datagram to the flow")
                context.eventLoop.execute {
                    log(.warning, "id: \(self.id) Closing channel for InboundHandlerUDP")
                    self.terminate(channel: context.channel)
                }
            }
        }
    }
}
