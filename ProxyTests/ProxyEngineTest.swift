//
//  ProxyEngineTest.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 18/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

@testable import SplitTunnelProxy
import Quick
import Nimble
import NetworkExtension

final class ProxyEngineTest: QuickSpec {
    override class func spec() {
        let config = SessionConfig(interface: MockNetworkInterface(), eventLoopGroup: nil)

        describe("ProxyEngineTest") {
            context("handleNewFlow") {
                context("when the app is not in either the vpnOnly or bypass lists") {
                    it("ignores a new TCP flow") {
                        let vpnState = VpnState(bypassApps: [], vpnOnlyApps: [""], networkInterface: "en0", serverAddress: "127.0.01", routeVpn: true, connected: false, groupName: "piavpn")

                        let mockSessionFactory = MockProxySessionFactory()
                        let engine = ProxyEngine(vpnState: vpnState, proxySessionFactory: mockSessionFactory, config: config)

                        let flow = MockFlowTCP()
                        flow.sourceAppSigningIdentifier = "com.foo.bar"

                        let willHandleFlow = engine.handleNewFlow(flow)
                        expect(willHandleFlow).to(equal(false))
                    }

                    it("ignores a new UDP flow") {
                        let vpnState = VpnState(bypassApps: [], vpnOnlyApps: [""], networkInterface: "en0", serverAddress: "127.0.01", routeVpn: true, connected: false, groupName: "piavpn")

                        let mockSessionFactory = MockProxySessionFactory()
                        let engine = ProxyEngine(vpnState: vpnState, proxySessionFactory: mockSessionFactory, config: config)

                        let flow = MockFlowUDP()
                        flow.sourceAppSigningIdentifier = "com.foo.bar"

                        let willHandleFlow = engine.handleNewFlow(flow)
                        expect(willHandleFlow).to(equal(false))
                    }
                }
                context("when the app is in the vpnOnly list and vpn is disconnected") {
                    it("blocks a new TCP flow") {
                        let vpnState = VpnState(bypassApps: [], vpnOnlyApps: ["com.apple.curl"], networkInterface: "en0", serverAddress: "127.0.01", routeVpn: true, connected: false, groupName: "piavpn")

                        let mockSessionFactory = MockProxySessionFactory()
                        let engine = ProxyEngine(vpnState: vpnState, proxySessionFactory: mockSessionFactory, config: config)

                        let flow = MockFlowTCP()
                        flow.sourceAppSigningIdentifier = "com.apple.curl"

                        // We still expect a true here (even though we block the flow) as we need to tell the OS we're taking control of the flow to be able to block it - a return value of true indicates we want control over it
                        let willHandleFlow = engine.handleNewFlow(flow)
                        expect(willHandleFlow).to(equal(true))
                        // The flow is killed
                        expect(flow.didCall("closeReadAndWrite")).to(equal(true))
                    }
                    it("blocks a new UDP flow") {
                        let vpnState = VpnState(bypassApps: [], vpnOnlyApps: ["com.apple.curl"], networkInterface: "en0", serverAddress: "127.0.01", routeVpn: true, connected: false, groupName: "piavpn")

                        let mockSessionFactory = MockProxySessionFactory()
                        let engine = ProxyEngine(vpnState: vpnState, proxySessionFactory: mockSessionFactory, config: config)

                        let flow = MockFlowUDP()
                        flow.sourceAppSigningIdentifier = "com.apple.curl"

                        let willHandleFlow = engine.handleNewFlow(flow)
                        expect(willHandleFlow).to(equal(true))
                        // The flow is killed
                        expect(flow.didCall("closeReadAndWrite")).to(equal(true))
                    }
                }

                context("when the app is in the bypass list and vpn is connected") {
                    it("manages a new TCP flow") {
                        let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: [], networkInterface: "en0", serverAddress: "127.0.01", routeVpn: true, connected: true, groupName: "piavpn")

                        let mockSessionFactory = MockProxySessionFactory()
                        let engine = ProxyEngine(vpnState: vpnState, proxySessionFactory: mockSessionFactory, config: config)

                        let flow = MockFlowTCP()
                        flow.sourceAppSigningIdentifier = "com.apple.curl"

                        let willHandleFlow = engine.handleNewFlow(flow)
                        expect(willHandleFlow).to(equal(true))
                        expect(flow.didCall("openFlow")).to(equal(true))
                    }

                    it("manages a new UDP flow") {
                        let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: [], networkInterface: "en0", serverAddress: "127.0.01", routeVpn: true, connected: true, groupName: "piavpn")

                        let mockSessionFactory = MockProxySessionFactory()
                        let engine = ProxyEngine(vpnState: vpnState, proxySessionFactory: mockSessionFactory, config: config)

                        let flow = MockFlowUDP()
                        flow.sourceAppSigningIdentifier = "com.apple.curl"

                        let willHandleFlow = engine.handleNewFlow(flow)
                        expect(willHandleFlow).to(equal(true))
                        expect(flow.didCall("openFlow")).to(equal(true))
                    }
                }
            }
        }
    }
}
