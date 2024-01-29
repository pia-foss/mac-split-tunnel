//
//  SplitTunnelProxyProviderTest.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 16/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

@testable import SplitTunnelProxy
import Quick
import Nimble
import NetworkExtension

final class SplitTunnelProxyProviderTest: QuickSpec {
    static let validOptions: Dictionary<String, Any> = [
        "bypassApps" : ["/Applications/Foo.app"],
        "vpnOnlyApps" : ["/Applications/Bar.app"],
        "bindInterface" : "en0",
        "serverAddress" : "127.0.0.1",
        "logFile" : "/foo/bar.log",
        "logLevel" : "debug",
        "routeVpn" : true,
        "isConnected" : true,
        // The name of the unix group pia whitelists in the firewall
        // This may be different when PIA is white-labeled
        "whitelistGroupName" : "piavpn"
    ]

    static let invalidOptions: Dictionary<String, Any> = [:]

    static func setupTestEnvironment() -> (MockProxyEngine, MockLogger, SplitTunnelProxyProvider) {
        let mockEngine = MockProxyEngine()
        let mockLogger = MockLogger()
        let provider = SplitTunnelProxyProvider()
        provider.engine = mockEngine
        provider.logger = mockLogger

        return (mockEngine, mockLogger, provider)
    }

    override class func spec() {
        describe("SplitTunnelProxyProviderTest") {

            // We cannot test this as it expects an actual NEAppProxyFlow which we
            // cannot construct ourselves
            context("handleNewFlow") {
            }

            context("handleAppMessage") {
                it("delegates the call") {
                    let (mockEngine, _, provider) = setupTestEnvironment()
                    let data = "quinn-the-eskimo".data(using: .utf8)
                    provider.handleAppMessage(data!, completionHandler: nil)
                    expect(mockEngine.didCallWithArgAt("handleAppMessage", index: 0, value: data)).to(beTrue())
                }
            }

            context("with invalid options") {
                context("when starting proxy") {
                    it("early exits after failing to create VpnState") {
                        let (_, mockLogger, provider) = setupTestEnvironment()
                        let completionHandler: (Error?) -> Void = { (error: Error?) in }

                        provider.startProxy(options: invalidOptions, completionHandler: completionHandler)

                        // Does call Logger.initializeLogger
                        // A call to Logger.initialize should always succeed - as we provide defaults and logging
                        // is very important to capture errors in subsequent steps
                        expect(mockLogger.didCall("initializeLogger")).to(equal(true))
                    }
                }
            }

            context("with valid options") {
                context("when starting proxy") {
                    it("initializes the logger") {
                        let (_, mockLogger, provider) = setupTestEnvironment()
                        let completionHandler: (Error?) -> Void = { (error: Error?) in }

                        provider.startProxy(options: Self.validOptions, completionHandler: completionHandler)

                        expect(mockLogger.didCall("initializeLogger")).to(equal(true))
                    }
                }
            }
        }
    }
}
