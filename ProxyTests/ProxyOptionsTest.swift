@testable import SplitTunnelProxy
import Quick
import Nimble

class ProxyOptionsSpec: QuickSpec {
    override class func spec() {
        describe("ProxyOptions") {
            context("when an option array is created") {
                // This is needed because ProxyOptions.create() contains log calls
                Logger.instance.initializeLogger(logLevel: "error", logFile: "/tmp/STProxy.log")

                it("should return the object if all required options are present") {
                    let correctOptions: [String : Any]? =
                        ["bypassApps" : ["Quinn", "app1"],
                        "vpnOnlyApps" : ["Eskimo", "app2"],
                        "networkInterface" : "en666",
                        "serverAddress" : "1.2.3.4",
                        "logFile" : "file.log",
                        "logLevel" : "debug",
                        "routeVpn" : true,
                        "connected" : true,
                        "whitelistGroupName" : "group1"]
                    expect(ProxyOptionsFactory().create(options: correctOptions)).toNot(beNil())
                }
                
                it("should return nil if some required options are missing") {
                    let missingOptions: [String : Any]? =
                        ["routeVpn" : true,
                        "connected" : true,
                        "whitelistGroupName" : "group1"]
                    expect(ProxyOptionsFactory().create(options: missingOptions)).to(beNil())
                }

                it("should return nil if some required options are the wrong type") {
                    let wrongTypeOptions: [String : Any]? =
                    ["bypassApps" : "",
                    "vpnOnlyApps" : "",
                    "networkInterface" : "en666",
                    "serverAddress" : "1.2.3.4",
                    "logFile" : "file.log",
                    "logLevel" : "debug",
                    "routeVpn" : true,
                    "connected" : true,
                    "whitelistGroupName" : "group1"]
                    expect(ProxyOptionsFactory().create(options: wrongTypeOptions)).to(beNil())
                }
            }
        }
    }
}
