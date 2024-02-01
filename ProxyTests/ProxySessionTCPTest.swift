//
//  ProxySessionTCPTest.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 14/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Quick
import Nimble
import NetworkExtension
import NIO

@testable import SplitTunnelProxyExtensionFramework
class ProxySessionTCPTest: QuickSpec {
    override class func spec() {
        let sessionConfig = SessionConfig(
            interface: MockNetworkInterface(),
            // We don't need this in tests, and it's not used anyway
            // since we set an explicit channel (using the session.channel setter)
            eventLoopGroup: nil
        )

        describe("ProxySessionTCP") {
            context("when starting a new TCP flow") {
                it("performs a read on the flow") {
                    // Empty data - so that the Flow fails the readData and early exits
                    let mockFlow = MockFlowTCP(data: nil)
                    // Create a mockChannel with a failed write - otherwise we will go into an infinite
                    // loop due to another read being scheduled on success
                    let mockChannel = MockChannel(isActive: false, successfulWrite: false)
                    let proxySession = ProxySessionTCP(flow: mockFlow, config: sessionConfig, id: 1)

                    // Set an explicit channel (to prevent ProxySession from creating one)
                    proxySession.channel = mockChannel
                    proxySession.start()

                    expect(mockFlow.didCall("readData")).to(equal(true))
                }
            }

            context("when a flow read succeeds") {
                // The proxy works by reading from the flow and then writing to the channel
                // so a successful read from the flow should result in a corresponding write to the channel
                it("should write to the channel") {
                    // A flow read will succeed when there's data available (so this one should succeed)
                    let data = Data([0x1])
                    let mockFlow = MockFlowTCP(data: data)
                    // Setup the mock with a failed write - to avoid infinite loops (i.e another readData being scheduled)
                    let mockChannel = MockChannel(isActive: true, successfulWrite: false)
                    let proxySession = ProxySessionTCP(flow: mockFlow, config: sessionConfig, id: 1)

                    proxySession.channel = mockChannel
                    proxySession.start()

                    let expectedBytes = ByteBuffer(bytes: data)
                    expect(mockChannel.didCallWithArgAt("writeAndFlush", index: 0, 
                                                        value: expectedBytes)).to(equal(true))
                }
            }

            context("when a flow read fails") {
                it("should close the flow and the channel") {
                    // Empty data - so that the Flow fails the readData and early exits
                    let mockFlow = MockFlowTCP(data: nil)
                    // Set the channel to isActive - so that it gets closed on failure
                    let mockChannel = MockChannel(isActive: true, successfulWrite: false)
                    let proxySession = ProxySessionTCP(flow: mockFlow, config: sessionConfig, id: 1)

                    proxySession.channel = mockChannel
                    proxySession.start()

                    // The flow is closed
                    expect(mockFlow.didCall("closeReadAndWrite")).to(equal(true))
                    // The channel is closed
                    expect(mockChannel.didCall("close")).to(equal(true))
                }
            }
        }
    }
}
