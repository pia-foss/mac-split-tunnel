@testable import SplitTunnelProxy
import Quick
import Nimble
import NetworkExtension

final class ProxyEngineTest: QuickSpec {
    override class func spec() {
        let vpnState = VpnState(bypassApps: [], vpnOnlyApps: [""],
                                networkInterface: "en0", serverAddress: "127.0.01",
                                routeVpn: true, connected: false, groupName: "piavpn")

        describe("ProxyEngineTest") {
            context("handleNewFlow") {
                it("delegates the call") {
                    let mockFlow = MockFlowTCP()
                    let mockFlowHandler = MockFlowHandler()
                    let proxyEngine = ProxyEngine(vpnState: vpnState)
                    proxyEngine.flowHandler = mockFlowHandler

                    _ = proxyEngine.handleNewFlow(mockFlow)

                    expect(mockFlowHandler.didCallWithArgAt("handleNewFlow", index: 0, value: mockFlow)).to(beTrue())
                    expect(mockFlowHandler.didCallWithArgAt("handleNewFlow", index: 1, value: vpnState)).to(beTrue())
                }
            }

            context("handleAppMessage") {
                let newVpnState = VpnState(bypassApps: [], vpnOnlyApps: [""],
                                           networkInterface: "en8", serverAddress: "127.0.01",
                                           routeVpn: false, connected: true, groupName: "piavpn")
                it("delegates the call") {
                    let proxyEngine = ProxyEngine(vpnState: vpnState)
                    let mockMessageHandler = MockMessageHandler(newVpnState: newVpnState)

                    let data = "message".data(using: .utf8)
                    proxyEngine.messageHandler = mockMessageHandler

                    proxyEngine.handleAppMessage(data!, completionHandler: nil)
                    expect(mockMessageHandler.didCallWithArgAt("handleAppMessage", index: 0, value: data)).to(beTrue())
                }

                it("updates VpnState") {
                    let proxyEngine = ProxyEngine(vpnState: vpnState)
                    // Simulate a state update as a result of handleAppMessage
                    let mockMessageHandler = MockMessageHandler(newVpnState: newVpnState)

                    let data = "message".data(using: .utf8)
                    proxyEngine.messageHandler = mockMessageHandler
                    
                    // This method delegates to MessageHandler. MessageHandler processes
                    // the raw data (which is JSON), grabs the new VpnState and then
                    // updates ProxyEngine.vpnState with the new state
                    proxyEngine.handleAppMessage(data!, completionHandler: nil)
                    expect(proxyEngine.vpnState).to(equal(newVpnState))
                }
            }
        }
    }
}
