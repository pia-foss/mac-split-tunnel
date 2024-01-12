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
        }
    }
}
