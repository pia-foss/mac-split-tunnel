//
//  InboundHandlerTCP.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 20/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NIO
import NetworkExtension

// Responsible receiving data on a TCP socket and
// writing that data to the corresponding flow
final class InboundHandlerTCP: InboundHandler {
    typealias ByteCountFunc = (UInt64) -> Void
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    let flow: FlowTCP
    let id: IDGenerator.ID
    let onBytesReceived: (UInt64) -> Void

    init(flow: FlowTCP, id: IDGenerator.ID, onBytesReceived: @escaping (UInt64) -> Void) {
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

        forwardToFlow(context: context, data: Data(bytes), onBytesReceived: onBytesReceived)
    }

    private func handleWriteError(context: ChannelHandlerContext, error: Error?) {
        log(.error, "id: \(self.id) \(self.flow.sourceAppSigningIdentifier) \(error!.localizedDescription) occurred when writing TCP data to the flow")
        context.eventLoop.execute {
            log(.warning, "id: \(self.id) Closing channel for InboundHandlerTCP")
            self.terminate(channel: context.channel)
        }
    }

    private func forwardToFlow(context: ChannelHandlerContext, data: Data, onBytesReceived: @escaping ByteCountFunc) {
        // new traffic is ready to be read on the socket
        // we want to write that data to the flow
        flow.write(data) { flowError in
            if flowError == nil {
                // No error, byes were written - just record the byteCount
                onBytesReceived(UInt64(data.count))
            } else {
                self.handleWriteError(context: context, error: flowError)
            }
        }
    }
}
