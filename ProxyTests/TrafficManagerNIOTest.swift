//
//  TrafficManagerNIO.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 12/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

@testable import SplitTunnelProxy
import Quick
import Nimble
import NetworkExtension
import NIO

class TrafficManagerNIOSpec: QuickSpec {
    override class func spec() {
        describe("TrafficManagerNIO") {
            context("when handling a TCP flow") {
                it("should create a TCP ProxySession") {
                    let mockFactory = MockProxySessionFactory()
                    let tm = TrafficManagerNIO(interfaceName: "en0", proxySessionFactory: mockFactory)
                    tm.handleFlowIO(MockFlowTCP())

                    expect(mockFactory.didCall("createTCP")).to(equal(true))
                    expect(mockFactory.didCall("createUDP")).to(equal(false))
                }
            }
            context("when handling a UDP flow") {
                it("should create a UDP ProxySession") {
                    let mockFactory = MockProxySessionFactory()
                    let tm = TrafficManagerNIO(interfaceName: "en0", proxySessionFactory: mockFactory)
                    tm.handleFlowIO(MockFlowUDP())

                    expect(mockFactory.didCall("createUDP")).to(equal(true))
                    expect(mockFactory.didCall("createTCP")).to(equal(false))
                }
            }
            context("id generation") {
                it("should generate a unique id each time") {
                    let mockFactory = MockProxySessionFactory()
                    let tm = TrafficManagerNIO(interfaceName: "en0", proxySessionFactory: mockFactory)
                    tm.handleFlowIO(MockFlowTCP())
                    tm.handleFlowIO(MockFlowUDP())

                    expect(mockFactory.didCallWithArgAt("createTCP", index: 2, value: UInt64(1))).to(equal(true))
                    expect(mockFactory.didCallWithArgAt("createUDP", index: 2, value: UInt64(2))).to(equal(true))
                }
            }
        }
    }
}
