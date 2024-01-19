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

class InboundHandlerTCPTest: QuickSpec {
    private static func setupTestEnvironment(onBytesReceived: @escaping (UInt64) -> Void = { _ in }, flowError: Error? = nil) -> (EmbeddedChannel, MockFlowTCP, (UInt64) -> Void) {
        let mockFlow = MockFlowTCP(data: nil, flowError: flowError)
        let channel = EmbeddedChannel()
        let handler = InboundHandlerTCP(flow: mockFlow, id: 1, onBytesReceived: onBytesReceived)
        try! channel.pipeline.addHandler(handler).wait()

        return (channel, mockFlow, onBytesReceived)
    }

    override class func spec() {
        describe("InboundHandlerTCP") {
            context("when new data arrives on the channel") {
                it("writes the new data to the corresponding flow") {
                    let (channel, mockFlow, _) = setupTestEnvironment()

                    var buffer = channel.allocator.buffer(capacity: 10)
                    buffer.writeString("Hello world")

                    let expectedData = Data(buffer.readableBytesView)
                    try channel.writeInbound(buffer)

                    expect(mockFlow.didCallWithArgAt("write", index: 0, value: expectedData)).to(equal(true))
                }

                it("updates bytesReceived") {
                    var count: UInt64 = 0
                    let onBytesReceived = { (byteCount: UInt64) in count = byteCount }
                    let (channel, _, _) = setupTestEnvironment(onBytesReceived: onBytesReceived)

                    var buffer = channel.allocator.buffer(capacity: 10)

                    let stringToWrite = "Hello world"
                    buffer.writeString(stringToWrite)
                    try channel.writeInbound(buffer)

                    expect(count).to(equal(UInt64(stringToWrite.count)))
                }

                it("terminates the channel if writing to the flow fails") {
                    // Just a simple error to simulate a flow.write failure
                    struct FakeError: Error {}

                    var count: UInt64 = 0
                    let onBytesReceived = { (byteCount: UInt64) in count = byteCount}
                    let (channel, _, _) = setupTestEnvironment(onBytesReceived: onBytesReceived, flowError: FakeError())

                    var buffer = channel.allocator.buffer(capacity: 10)
                    buffer.writeString("Hello world")
                    try channel.writeInbound(buffer)

                    // Bytecount not updated as the write failed
                    expect(count).to(equal(UInt64(0)))
                }
            }
        }
    }
}
