import Foundation
import NetworkExtension
import NIO

// Manages a single TCP proxy session from an originating app and proxying
// it to remote endpoint via the corresponding NIO Channel. Facilitates read and write
// operations in both directions (app-to-proxy and proxy-to-destination and back again).
// Uses the InboundHandlerTCP helper class to handle packets
// incoming from the remote endpoint.
final class ProxySessionTCP: ProxySession {
    let flow: FlowTCP
    let config: SessionConfig
    // Unique identifier for this session
    public let id: IDGenerator.ID
    // Made public to allow for mocking/stubbing in tests
    public var channel: SessionChannel!

    // Number of bytes transmitted and received
    var txBytes: UInt64 = 0
    var rxBytes: UInt64 = 0

    init(flow: FlowTCP, config: SessionConfig, id: IDGenerator.ID) {
        self.flow = flow
        self.config = config
        self.id = id
    }

    deinit {
        log(.debug, "id: \(self.id) Destructor: ProxySession closed." +
            " rxBytes=\(formatByteCount(rxBytes)) txBytes=\(formatByteCount(txBytes))")
    }

    public func start() {
        let onBytesTransmitted = { (byteCount: UInt64) in self.txBytes &+= byteCount }
        let onBytesReceived = { (byteCount: UInt64) in self.rxBytes &+= byteCount }

        if self.channel != nil {
            FlowProcessorTCP(id: id, flow: flow, channel: channel)
                .scheduleFlowRead(onBytesTransmitted)
        } else {
            createChannel(onBytesReceived).whenSuccess { nioChannel in
                FlowProcessorTCP(id: self.id, flow: self.flow, 
                    channel: ChannelWrapper(nioChannel))
                    .scheduleFlowRead(onBytesTransmitted)
            }
        }
    }

    public func createChannel(_ onBytesReceived: @escaping (UInt64) -> Void) 
        -> EventLoopFuture<Channel> {
        let channelFuture = ChannelCreatorTCP(id: id, flow: flow,
                                              config: config).create(onBytesReceived)

        channelFuture.whenFailure { error in
            log(.error, "id: \(self.id) Unable to create channel: \(error)," +
                " dropping the flow.")
            self.flow.closeReadAndWrite()
        }

        return channelFuture
    }

    public func terminate() {
        Self.terminateProxySession(id: id, channel: channel, flow: flow)
    }
}
