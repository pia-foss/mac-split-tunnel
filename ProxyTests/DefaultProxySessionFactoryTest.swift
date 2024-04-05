import Foundation

import Quick
import Nimble
import NetworkExtension
import NIO

@testable import SplitTunnelProxyExtensionFramework
class DefaultProxySessionFactoryTest: QuickSpec {
    override class func spec() {
        let sessionConfig = SessionConfig(
            bindIp: "", // Not used
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
