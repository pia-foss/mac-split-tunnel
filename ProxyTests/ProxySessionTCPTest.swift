//
//  ProxySessionTCPTest.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 14/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

@testable import SplitTunnelProxy
import Quick
import Nimble
import NetworkExtension
import NIO

class ProxySessionTCPTest: QuickSpec {
    override class func spec() {
        let sessionConfig = SessionConfig(
            eventLoopGroup: nil,
            interfaceAddress: getNetworkInterfaceIP(interfaceName: "en0")!
        )

        describe("ProxySessionTCP") {
            context("when starting a new TCP flow") {
                it("should schedule a read on the flow") {
                    let mockFlow = MockFlowTCP()
                    let proxySession = ProxySessionTCP(flow: mockFlow, config: sessionConfig, id: 1)
                    proxySession.channel = EmbeddedChannel()
                    proxySession.start()

                    expect(mockFlow.didCall("readData")).to(equal(true))
                }
            }
        }
    }
}
