import Quick
import Nimble
import NetworkExtension

@testable import SplitTunnelProxyExtensionFramework
final class FlowHandlerTest: QuickSpec {
    override class func spec() {
        let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: [""],
                                networkInterface: "en0", serverAddress: "127.0.01",
                                routeVpn: true, connected: true, groupName: "piavpn")

        describe("FlowHandlerTest") {
            context("handleNewFlow") {
                context("app is not in bypass or vpnOnly list") {
                    it("ignores the flow") {
                        let mockFlow = MockFlowTCP()
                        mockFlow.sourceAppSigningIdentifier = "com.apple.notfound"
                        let mockFactory = MockProxySessionFactory()
                        let flowHandler = FlowHandler()
                        flowHandler.proxySessionFactory = mockFactory

                        let result = flowHandler.handleNewFlow(mockFlow, vpnState: vpnState)

                        // false indicates the flow will not be handled by us
                        expect(result).to(beFalse())
                    }
                }

                context("the app is in the bypass list and vpn is connected") {
                    let connectedVpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: [""],
                                            networkInterface: "en0", serverAddress: "127.0.01",
                                            routeVpn: true, connected: true, groupName: "piavpn")

                    it("manages the app with a TCP flow") {
                        let mockFlow = MockFlowTCP()
                        mockFlow.sourceAppSigningIdentifier = "com.apple.curl"
                        let mockFactory = MockProxySessionFactory()
                        let flowHandler = FlowHandler()
                        flowHandler.proxySessionFactory = mockFactory

                        let result = flowHandler.handleNewFlow(mockFlow, vpnState: connectedVpnState)

                        expect(result).to(beTrue())
                        expect(mockFactory.didCallWithArgAt("createTCP", index: 0, value: mockFlow)).to(beTrue())
                        expect(mockFlow.didCall("openFlow")).to(beTrue())
                    }

                    it("manages the app with a UDP flow") {
                        let mockFlow = MockFlowUDP()
                        mockFlow.sourceAppSigningIdentifier = "com.apple.curl"
                        let mockFactory = MockProxySessionFactory()
                        let flowHandler = FlowHandler()
                        flowHandler.proxySessionFactory = mockFactory

                        let result = flowHandler.handleNewFlow(mockFlow, vpnState: connectedVpnState)

                        expect(result).to(beTrue())
                        expect(mockFactory.didCallWithArgAt("createUDP", index: 0, value: mockFlow)).to(beTrue())
                        expect(mockFlow.didCall("openFlow")).to(beTrue())
                    }
                }

                context("the app is in the bypass list and vpn is disconnected") {
                    let disconnectedVpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: [""],
                                                        networkInterface: "en0", serverAddress: "127.0.01",
                                                        routeVpn: true, connected: false, groupName: "piavpn")
                    it("ignores the app") {
                        let mockFlow = MockFlowTCP()
                        mockFlow.sourceAppSigningIdentifier = "com.apple.curl"
                        let mockFactory = MockProxySessionFactory()
                        let flowHandler = FlowHandler()
                        flowHandler.proxySessionFactory = mockFactory

                        let result = flowHandler.handleNewFlow(mockFlow, vpnState: disconnectedVpnState)

                        expect(result).to(beFalse())
                    }
                }

                context("the app is in the vpnOnly list and vpn is connected") {
                    let disconnectedVpnState = VpnState(bypassApps: [], vpnOnlyApps: ["com.google.chrome"],
                                                        networkInterface: "en0", serverAddress: "127.0.01",
                                                        routeVpn: true, connected: true, groupName: "piavpn")
                    it("ignores the app") {
                        let mockFlow = MockFlowTCP()
                        mockFlow.sourceAppSigningIdentifier = "com.google.chrome"
                        let mockFactory = MockProxySessionFactory()
                        let flowHandler = FlowHandler()
                        flowHandler.proxySessionFactory = mockFactory

                        let result = flowHandler.handleNewFlow(mockFlow, vpnState: disconnectedVpnState)

                        expect(result).to(beFalse())
                    }
                }

                context("the app is in the vpnOnly list and vpn is disconnected") {
                    let disconnectedVpnState = VpnState(bypassApps: [], vpnOnlyApps: ["com.google.chrome"],
                                                        networkInterface: "en0", serverAddress: "127.0.01",
                                                        routeVpn: true, connected: false, groupName: "piavpn")
                    it("blocks the app") {
                        let mockFlow = MockFlowTCP()
                        mockFlow.sourceAppSigningIdentifier = "com.google.chrome"
                        let mockFactory = MockProxySessionFactory()
                        let flowHandler = FlowHandler()
                        flowHandler.proxySessionFactory = mockFactory

                        let result = flowHandler.handleNewFlow(mockFlow, vpnState: disconnectedVpnState)

                        // We handle it so that we can block it (otherwise the default behaviour will occur
                        // which is for it NOT to be blocked.)
                        expect(result).to(beTrue())
                        // we block the flow by closing it
                        expect(mockFlow.didCall("closeReadAndWrite")).to(beTrue())
                    }
                }
            }
        }
    }
}
