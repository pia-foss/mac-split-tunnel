import Quick
import Nimble
import NetworkExtension
@testable import SplitTunnelProxyExtensionFramework

final class MessageHandlerTest: QuickSpec {
    override class func spec() {
        describe("MessageHandlerTest") {
            context("with invalid json") {
                // Invalid as it misses many required fields
                let invalidJson: [String: Any] = [
                    "isConnected": true
                ]

                it("does not invoke onProcessedMessage callback") {
                    let data = try JSONSerialization.data(withJSONObject: invalidJson, options: [])
                    let messageHandler = MessageHandler()

                    var isInvoked = false
                    messageHandler.handleAppMessage(data, nil) { message in
                        isInvoked = true
                    }
                    
                    expect(isInvoked).to(beFalse())
                }
            }

            context("with valid json") {
                let validJson: [String: Any] = [
                    "bypassApps": ["com.bypass"],
                    "vpnOnlyApps": ["com.vpnonly"],
                    "bindInterface": "en0",
                    "serverAddress": "1.1.1.1",
                    "routeVpn": true,
                    "isConnected": true,
                    "whitelistGroupName": "acmevpn"
                ]

                it("decodes the json message and invokes onProcessedMessage callback") {
                    let data = try JSONSerialization.data(withJSONObject: validJson, options: [])
                    let messageHandler = MessageHandler()

                    var vpnState = VpnState()
                    messageHandler.handleAppMessage(data, nil) { message in
                        switch message {
                        case .VpnStateUpdateMessage(let newState):
                            vpnState = newState
                        }
                    }

                    expect(vpnState.bypassApps).to(equal(["com.bypass"]))
                    expect(vpnState.vpnOnlyApps).to(equal(["com.vpnonly"]))
                    expect(vpnState.networkInterface).to(equal("en0"))
                    expect(vpnState.serverAddress).to(equal("1.1.1.1"))
                    expect(vpnState.routeVpn).to(equal(true))
                    expect(vpnState.connected).to(equal(true))
                    expect(vpnState.groupName).to(equal("acmevpn"))
                }
                
                // A response completion handler is an optional callback that is invoked
                // to send a reply to the sender of the message
                context("when a response completion handler is provided") {
                    it("calls the response completion handler") {
                        let data = try JSONSerialization.data(withJSONObject: validJson, options: [])
                        let messageHandler = MessageHandler()
                        var isInvoked = false

                        let responseHandler = { (data: Data?) in isInvoked = true}
                        messageHandler.handleAppMessage(data, responseHandler) { message in }

                        expect(isInvoked).to(beTrue())
                    }
                }
            }
        }
    }
}
