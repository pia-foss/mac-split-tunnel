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
    struct TestEnv {
        let mockFlow: MockFlowTCP
        let channel: EmbeddedChannel
        let inboundHandler: InboundHandlerTCP
        let onBytesReceived: (UInt64) -> Void
    }

    private static func setupTestEnvironment(onBytesReceived: @escaping (UInt64) -> Void = { _ in }, flowError: Error? = nil) -> TestEnv {

        let mockFlow = MockFlowTCP(data: nil, flowError: flowError)
        let channel = EmbeddedChannel()
        let inboundHandler = InboundHandlerTCP(flow: mockFlow, id: 1, onBytesReceived: onBytesReceived)
        try! channel.pipeline.addHandler(inboundHandler).wait()

        let env: TestEnv = TestEnv(mockFlow: mockFlow,
                                   channel: channel, inboundHandler: inboundHandler,
                                   onBytesReceived: onBytesReceived)

        return env
    }

    override class func spec() {
        // We test InboundHandlerTCP indirectly via the channel - writing to the channel
        // will cause the inboundHandlerTCP.channelRead method to be called
        // which will write to the corresponding Flow
        describe("InboundHandlerTCP") {
            context("when new data arrives on the channel") {
                it("writes the new data to the corresponding flow") {
                    let env = setupTestEnvironment()

                    var buffer = env.channel.allocator.buffer(capacity: 10)
                    buffer.writeString("Hello world")

                    let expectedData = Data(buffer.readableBytesView)
                    try env.channel.writeInbound(buffer)

                    expect(env.mockFlow.didCallWithArgAt("write", index: 0, value: expectedData)).to(equal(true))
                }

                it("updates bytesReceived") {
                    var count: UInt64 = 0
                    let onBytesReceived = { (byteCount: UInt64) in count = byteCount }
                    let env = setupTestEnvironment(onBytesReceived: onBytesReceived)

                    var buffer = env.channel.allocator.buffer(capacity: 10)

                    let stringToWrite = "Hello world"
                    buffer.writeString(stringToWrite)
                    try env.channel.writeInbound(buffer)

                    expect(count).to(equal(UInt64(stringToWrite.count)))
                }

                it("does not update bytesReceived if writing to the flow fails") {
                    // Just a simple error to simulate a flow.write failure
                    struct FakeError: Error {}

                    var count: UInt64 = 0
                    let onBytesReceived = { (byteCount: UInt64) in count = byteCount}

                    // The flowError will cause the MockFlowTCP write() method to fail
                    let env = setupTestEnvironment(onBytesReceived: onBytesReceived, flowError: FakeError())

                    var buffer = env.channel.allocator.buffer(capacity: 10)
                    buffer.writeString("Hello world")
                    try env.channel.writeInbound(buffer)

                    // Bytecount not updated as the write failed
                    expect(count).to(equal(UInt64(0)))
                }
            }
        }
    }
}
