//
//  ProxySessionUDPTest.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 15/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

import Quick
import Nimble
import NetworkExtension
import NIO

@testable import SplitTunnelProxyExtensionFramework
class ProxySessionUDPTest: QuickSpec {
    override class func spec() {
        let sessionConfig = SessionConfig(
            bindIp: "", // Not used,
            // We don't need this in tests, and it's not used anyway
            // since we set an explicit channel (using the session.channel setter)
            eventLoopGroup: nil)

        describe("ProxySessionUDP") {
            context("when starting a new UDP flow") {
                it("performs a read on the flow") {
                    // Empty data - so that the Flow fails the readData and early exits
                    let mockFlow = MockFlowUDP(data: nil)
                    // Create a mockChannel with a failed write - otherwise we will go into an infinite
                    // loop due to another read being scheduled on success
                    let mockChannel = MockChannel(isActive: false, successfulWrite: false)
                    let proxySession = ProxySessionUDP(flow: mockFlow, config: sessionConfig, id: 1)

                    // Set an explicit channel (to prevent ProxySession from creating one)
                    proxySession.channel = mockChannel
                    proxySession.start()

                    expect(mockFlow.didCall("readDatagrams")).to(equal(true))
                }
            }

            context("when a flow read succeeds") {
                // The proxy works by reading from the flow and then writing to the channel
                // so a successful read from the flow should result in a corresponding write to the channel
                it("should write to the channel") {
                    let endpoint = NWHostEndpoint(hostname: "8.8.8.8", port: "1337")

                    // A flow read will succeed when there's data available (so this one should succeed)
                    let mockFlow = MockFlowUDP(data: [Data([0x1])], endpoints: [endpoint] )
                    // Setup the mock with a failed write - to avoid infinite loops (i.e another readData being scheduled)
                    let mockChannel = MockChannel(isActive: true, successfulWrite: false)
                    let proxySession = ProxySessionUDP(flow: mockFlow, config: sessionConfig, id: 1)

                    proxySession.channel = mockChannel
                    proxySession.start()

                    expect(mockChannel.didCall("writeAndFlush")).to(equal(true))
                }
            }

            context("when a flow read fails") {
                it("should close the flow and the channel") {
                    // Empty data - so that the Flow fails the readData and early exits
                    let mockFlow = MockFlowUDP(data: nil)
                    // Set the channel to isActive - so that it gets closed on failure
                    let mockChannel = MockChannel(isActive: true, successfulWrite: false)
                    let proxySession = ProxySessionUDP(flow: mockFlow, config: sessionConfig, id: 1)

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
