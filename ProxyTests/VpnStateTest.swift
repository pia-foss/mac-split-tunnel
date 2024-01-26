@testable import SplitTunnelProxy
import Quick
import Nimble

class VpnStateSpec: QuickSpec {
    override class func spec() {
        describe("ProxyOptions") {
            context("when an option array is created") {
                it("should return the object if all required options are present") {
                    let correctOptions: [String : Any]? =
                        ["bypassApps" : ["Quinn", "app1"],
                        "vpnOnlyApps" : ["Eskimo", "app2"],
                        "bindInterface" : "en666",
                        "serverAddress" : "1.2.3.4",
                        "logFile" : "file.log",
                        "logLevel" : "debug",
                        "routeVpn" : true,
                        "isConnected" : true,
                        "whitelistGroupName" : "group1"]
                    expect(VpnStateFactory.create(options: correctOptions)).toNot(beNil())
                }
                
                it("should return nil if some required options are missing") {
                    let missingOptions: [String : Any]? =
                        ["routeVpn" : true,
                        "isConnected" : true,
                        "whitelistGroupName" : "group1"]
                    expect(VpnStateFactory.create(options: missingOptions)).to(beNil())
                }

                it("should return nil if some required options are the wrong type") {
                    let wrongTypeOptions: [String : Any]? =
                    ["bypassApps" : "",
                    "vpnOnlyApps" : "",
                    "bindInterface" : "en666",
                    "serverAddress" : "1.2.3.4",
                    "logFile" : "file.log",
                    "logLevel" : "debug",
                    "routeVpn" : true,
                    "isConnected" : true,
                    "whitelistGroupName" : "group1"]
                    expect(VpnStateFactory.create(options: wrongTypeOptions)).to(beNil())
                }
            }
        }
    }
}
