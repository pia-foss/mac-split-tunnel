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
        describe("ProxyEngineTest") {
            context("handleNewFlow") {
                context("when the app is not in vpnOnly or bypass lists") {
                    it("ignores a new TCP flow") {
                        let vpnState = VpnState(bypassApps: [], vpnOnlyApps: [""], networkInterface: "en0", serverAddress: "127.0.01", routeVpn: true, connected: false, groupName: "piavpn")

                        let mockTrafficManager = MockTrafficManager()

                        let engine = ProxyEngine()
                        engine.trafficManager = mockTrafficManager
                        engine.vpnState = vpnState

                        let flow = MockFlowTCP()
                        flow.sourceAppSigningIdentifier = "com.foo.bar"

                        let result = engine.handleNewFlow(flow)
                        expect(result).to(equal(false))
                    }

                    it("ignores a new UDP flow") {
                        let vpnState = VpnState(bypassApps: [], vpnOnlyApps: [""], networkInterface: "en0", serverAddress: "127.0.01", routeVpn: true, connected: false, groupName: "piavpn")

                        let mockTrafficManager = MockTrafficManager()

                        let engine = ProxyEngine()
                        engine.trafficManager = mockTrafficManager
                        engine.vpnState = vpnState

                        let flow = MockFlowUDP()
                        flow.sourceAppSigningIdentifier = "com.foo.bar"

                        let result = engine.handleNewFlow(flow)
                        expect(result).to(equal(false))
                    }
                }
                context("when the app is in the vpnOnly list and vpn is disconnected") {
                    it("blocks a new TCP flow") {
                        let vpnState = VpnState(bypassApps: [], vpnOnlyApps: ["com.apple.curl"], networkInterface: "en0", serverAddress: "127.0.01", routeVpn: true, connected: false, groupName: "piavpn")

                        let mockTrafficManager = MockTrafficManager()

                        let engine = ProxyEngine()
                        engine.trafficManager = mockTrafficManager
                        engine.vpnState = vpnState

                        let flow = MockFlowTCP()
                        flow.sourceAppSigningIdentifier = "com.apple.curl"

                        // We still expect a true here (even though we block the flow) as we need to tell the OS we're taking control of the flow to be able to block it - a return value of true indicates we want control over it
                        let result = engine.handleNewFlow(flow)
                        expect(result).to(equal(true))

                        expect(flow.didCall("closeReadAndWrite")).to(equal(true))
                    }
                    it("blocks a new UDP flow") {
                        let vpnState = VpnState(bypassApps: [], vpnOnlyApps: ["com.apple.curl"], networkInterface: "en0", serverAddress: "127.0.01", routeVpn: true, connected: false, groupName: "piavpn")

                        let mockTrafficManager = MockTrafficManager()

                        let engine = ProxyEngine()
                        engine.trafficManager = mockTrafficManager
                        engine.vpnState = vpnState

                        let flow = MockFlowUDP()
                        flow.sourceAppSigningIdentifier = "com.apple.curl"

                        // We still expect a true here (even though we block the flow) as we need to tell the OS we're taking control of the flow to be able to block it - a return value of true indicates we want control over it
                        let result = engine.handleNewFlow(flow)
                        expect(result).to(equal(true))

                        expect(flow.didCall("closeReadAndWrite")).to(equal(true))
                    }
                }

                context("when the app is in the bypass list and vpn is connected") {
                    it("manages a new TCP flow") {
                        let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: [], networkInterface: "en0", serverAddress: "127.0.01", routeVpn: true, connected: true, groupName: "piavpn")

                        let mockTrafficManager = MockTrafficManager()

                        let engine = ProxyEngine()
                        engine.trafficManager = mockTrafficManager
                        engine.vpnState = vpnState

                        let flow = MockFlowTCP()
                        flow.sourceAppSigningIdentifier = "com.apple.curl"

                        let result = engine.handleNewFlow(flow)
                        expect(result).to(equal(true))

                        expect(flow.didCall("openFlow")).to(equal(true))
                        expect(mockTrafficManager.didCall("handleFlowIO")).to(equal(true))
                    }

                    it("manages a new UDP flow") {
                        let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: [], networkInterface: "en0", serverAddress: "127.0.01", routeVpn: true, connected: true, groupName: "piavpn")

                        let mockTrafficManager = MockTrafficManager()

                        let engine = ProxyEngine()
                        engine.trafficManager = mockTrafficManager
                        engine.vpnState = vpnState

                        let flow = MockFlowUDP()
                        flow.sourceAppSigningIdentifier = "com.apple.curl"

                        let result = engine.handleNewFlow(flow)
                        expect(result).to(equal(true))

                        expect(flow.didCall("openFlow")).to(equal(true))
                        expect(mockTrafficManager.didCall("handleFlowIO")).to(equal(true))
                    }
                }
            }
        }
    }
}
