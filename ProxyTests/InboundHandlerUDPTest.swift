//
//  InboundHandlerTCPTest.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 19/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

@testable import SplitTunnelProxy
import Quick
import Nimble
import NetworkExtension
import NIO

class InboundHandlerUDPTest: QuickSpec {
    private static func setupTestEnvironment(onBytesReceived: @escaping (UInt64) -> Void = { _ in }, flowError: Error? = nil) -> (EmbeddedChannel, MockFlowUDP, (UInt64) -> Void) {
        let mockFlow = MockFlowUDP(data: nil, flowError: flowError)
        let channel = EmbeddedChannel()
        let handler = InboundHandlerUDP(flow: mockFlow, id: 1, onBytesReceived: onBytesReceived)
        try! channel.pipeline.addHandler(handler).wait()

        return (channel, mockFlow, onBytesReceived)
    }

    override class func spec() {
        describe("InboundHandlerUDP") {
            context("when new data arrives on the channel") {
                it("writes the new data to the corresponding flow") {
                    let (channel, mockFlow, _) = setupTestEnvironment()

                    var buffer = channel.allocator.buffer(capacity: 10)
                    buffer.writeString("Hello world")

                    let host = "1.1.1.1"
                    let port = 1337

                    // Note this are arrays for UDP
                    let expectedData = [Data(buffer.readableBytesView)]
                    let expectedEndpoints = [NWHostEndpoint(hostname: host, port: String(port))]
                    // UDP also requires an endpoint
                    let endpoint = try SocketAddress(ipAddress: host, port: port)
                    let envelope = AddressedEnvelope<ByteBuffer>(remoteAddress: endpoint, data: buffer)
                    try channel.writeInbound(envelope)

                    expect(mockFlow.didCallWithArgAt("writeDatagrams", index: 0, value: expectedData)).to(equal(true))
                    expect(mockFlow.didCallWithArgAt("writeDatagrams", index: 1, value: expectedEndpoints)).to(equal(true))
                }

                it("updates bytesReceived") {
                    var count: UInt64 = 0
                    let onBytesReceived = { (byteCount: UInt64) in count = byteCount }
                    let (channel, _, _) = setupTestEnvironment(onBytesReceived: onBytesReceived)

                    var buffer = channel.allocator.buffer(capacity: 10)

                    let stringToWrite = "Hello world"
                    buffer.writeString(stringToWrite)

                    let host = "1.1.1.1"
                    let port = 1337

                    // UDP also requires an endpoint
                    let endpoint = try SocketAddress(ipAddress: host, port: port)
                    let envelope = AddressedEnvelope<ByteBuffer>(remoteAddress: endpoint, data: buffer)
                    try channel.writeInbound(envelope)

                    expect(count).to(equal(UInt64(stringToWrite.count)))
                }

                it("does not update bytesReceived if writing to the flow fails") {
                    // Just a simple error to simulate a flow.write failure
                    struct FakeError: Error {}

                    var count: UInt64 = 0
                    let onBytesReceived = { (byteCount: UInt64) in count = byteCount}
                    let (channel, _, _) = setupTestEnvironment(onBytesReceived: onBytesReceived, flowError: FakeError())

                    var buffer = channel.allocator.buffer(capacity: 10)
                    buffer.writeString("Hello world")
                    let host = "1.1.1.1"
                    let port = 1337

                    // UDP also requires an endpoint
                    let endpoint = try SocketAddress(ipAddress: host, port: port)
                    let envelope = AddressedEnvelope<ByteBuffer>(remoteAddress: endpoint, data: buffer)
                    try channel.writeInbound(envelope)

                    // Bytecount not updated as the write failed
                    expect(count).to(equal(UInt64(0)))
                }
            }
        }
    }
}
