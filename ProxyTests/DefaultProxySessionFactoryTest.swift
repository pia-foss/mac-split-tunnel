//
//  DefaultProxySessionFactoryTest.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 19/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

import Quick
import Nimble
import NetworkExtension
import NIO

@testable import SplitTunnelProxyExtensionFramework
class DefaultProxySessionFactoryTest: QuickSpec {
    override class func spec() {
        let sessionConfig = SessionConfig(
            interface: MockNetworkInterface(),
            // We don't need this in tests, and it's not used anyway
            // since we set an explicit channel (using the session.channel setter)
            eventLoopGroup: nil)

        describe("DefaultProxySessionFactory") {
            it("creates a ProxySessionUDP when given a FlowUDP") {
                let mockFlow = MockFlowUDP()
                let factory = DefaultProxySessionFactory()
                let session = factory.createUDP(flow: mockFlow, config: sessionConfig, id: 1)
                expect(session is ProxySessionUDP ).to(equal(true))
            }
            it("creates a ProxySessionTCP when given a FlowTCP") {
                let mockFlow = MockFlowTCP()
                let factory = DefaultProxySessionFactory()
                let session = factory.createTCP(flow: mockFlow, config: sessionConfig, id: 1)
                expect(session is ProxySessionTCP ).to(equal(true))
            }
        }
    }
}
