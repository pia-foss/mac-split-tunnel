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

class SplitTunnelProxyProviderTest: QuickSpec {
    static let validOptions: Dictionary<String, Any> = [
        "bypassApps" : ["/Applications/Foo.app"],
        "vpnOnlyApps" : ["/Applications/Bar.app"],
        "networkInterface" : "en0",
        "serverAddress" : "127.0.0.1",
        "logFile" : "/foo/bar.log",
        "logLevel" : "debug",
        "routeVpn" : true,
        "connected" : true,
        // The name of the unix group pia whitelists in the firewall
        // This may be different when PIA is white-labeled
        "whitelistGroupName" : "piavpn"
    ]

    static let invalidOptions: Dictionary<String, Any> = [
        "networkInterface" : "en0",
        "serverAddress" : "127.0.0.1",
        "logFile" : "/foo/bar.log",
        "logLevel" : "debug",
        "routeVpn" : true,
        "connected" : true,
        // The name of the unix group pia whitelists in the firewall
        // This may be different when PIA is white-labeled
        "whitelistGroupName" : "piavpn"
    ]

    override class func spec() {
        describe("SplitTunnelProxyProviderTest") {
            context("with invalid options") {
                it("early exits after failing to create ProxyOptions") {
                    let mockEngine = MockProxyEngine()
                    let mockLogger = MockLogger()
                    let mockProxyOptionsFactory = MockProxyOptionsFactory()
                    let provider = SplitTunnelProxyProvider()
                    provider.engine = mockEngine
                    provider.logger = mockLogger
                    provider.proxyOptionsFactory = mockProxyOptionsFactory

                    let completionHandler: (Error?) -> Void = { (error: Error?) in }

                    provider.startProxy(options: [:], completionHandler: completionHandler)

                    // Does call ProxyOptionsFactory.create
                    expect(mockProxyOptionsFactory.didCall("create")).to(equal(true))

                    // Fails to call subsequent methods (as the failure above causes an early exit)
                    expect(mockEngine.didCall("whitelistProxyInFirewall")).to(equal(false))
                    expect(mockEngine.didCall("setTunnelNetworkSettings")).to(equal(false))
                }
            }

            context("with valid options") {
                context("when starting proxy") {
                    it("initializes the logger") {
                        let mockEngine = MockProxyEngine()
                        let mockLogger = MockLogger()
                        let mockProxyOptionsFactory = MockProxyOptionsFactory()
                        let provider = SplitTunnelProxyProvider()
                        provider.engine = mockEngine
                        provider.logger = mockLogger
                        provider.proxyOptionsFactory = mockProxyOptionsFactory

                        let completionHandler: (Error?) -> Void = { (error: Error?) in }

                        provider.startProxy(options: Self.validOptions, completionHandler: completionHandler)

                        expect(mockLogger.didCall("initializeLogger")).to(equal(true))
                    }

                    it("creates a ProxyOptions instance") {
                        let mockEngine = MockProxyEngine()
                        let mockLogger = MockLogger()
                        let mockProxyOptionsFactory = MockProxyOptionsFactory()
                        let provider = SplitTunnelProxyProvider()
                        provider.engine = mockEngine
                        provider.logger = mockLogger
                        provider.proxyOptionsFactory = mockProxyOptionsFactory

                        let completionHandler: (Error?) -> Void = { (error: Error?) in }

                        provider.startProxy(options: Self.validOptions, completionHandler: completionHandler)

                        expect(mockProxyOptionsFactory.didCall("create")).to(equal(true))
                    }

                    it("whitelists the proxy in the firewall") {
                        let mockEngine = MockProxyEngine()
                        let mockLogger = MockLogger()
                        let mockProxyOptionsFactory = MockProxyOptionsFactory()
                        let provider = SplitTunnelProxyProvider()
                        provider.engine = mockEngine
                        provider.logger = mockLogger
                        provider.proxyOptionsFactory = mockProxyOptionsFactory

                        let completionHandler: (Error?) -> Void = { (error: Error?) in }

                        provider.startProxy(options: Self.validOptions, completionHandler: completionHandler)

                        expect(mockEngine.didCallWithArgAt("whitelistProxyInFirewall", index: 0, value: Self.validOptions["whitelistGroupName"]! as! String)).to(equal(true))
                    }

                    it("sets tunnel network settings") {
                        let mockEngine = MockProxyEngine()
                        let mockLogger = MockLogger()
                        let mockProxyOptionsFactory = MockProxyOptionsFactory()
                        let provider = SplitTunnelProxyProvider()
                        provider.engine = mockEngine
                        provider.logger = mockLogger
                        provider.proxyOptionsFactory = mockProxyOptionsFactory

                        let completionHandler: (Error?) -> Void = { (error: Error?) in }

                        provider.startProxy(options: Self.validOptions, completionHandler: completionHandler)

                        expect(mockEngine.didCallWithArgAt("setTunnelNetworkSettings", index: 0, value: Self.validOptions["serverAddress"]! as! String )).to(equal(true))
                        expect(mockEngine.didCallWithArgAt("setTunnelNetworkSettings", index: 1, value: provider)).to(equal(true))
                    }
                }
            }
        }
    }
}
