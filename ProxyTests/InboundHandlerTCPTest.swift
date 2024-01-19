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
    override class func spec() {
        describe("InboundHandlerTCP") {
            context("when new data arrives on the channel") {
                it("writes the new data to the corresponding flow") {
                    let onBytesReceived = { (byteCount: UInt64) in }
                    // We set the mock up to have no data to be read and no errors
                    let mockFlow = MockFlowTCP(data: nil, flowError: nil)
                    let channel = EmbeddedChannel()
                    let handler = InboundHandlerTCP(flow: mockFlow, id: 1, onBytesReceived: onBytesReceived)
                    try channel.pipeline.addHandler(handler).wait()

                    var buffer = channel.allocator.buffer(capacity: 10)
                    buffer.writeString("Hello world")

                    let expectedData = Data(buffer.readableBytesView)
                    try channel.writeInbound(buffer)

                    expect(mockFlow.didCallWithArgAt("write", index: 0, value: expectedData)).to(equal(true))
                }

                it("updates bytesReceived") {
                    var count: UInt64 = 0
                    let onBytesReceived = { (byteCount: UInt64) in count = byteCount }
                    let mockFlow = MockFlowTCP(data: nil, flowError: nil)
                    let channel = EmbeddedChannel()
                    let handler = InboundHandlerTCP(flow: mockFlow, id: 1, onBytesReceived: onBytesReceived)
                    try channel.pipeline.addHandler(handler).wait()

                    var buffer = channel.allocator.buffer(capacity: 10)

                    let stringToWrite = "Hello world"
                    buffer.writeString(stringToWrite)
                    try channel.writeInbound(buffer)

                    expect(count).to(equal(UInt64(stringToWrite.count)))
                }
            }
        }
    }
}
