import Quick
import Nimble

@testable import SplitTunnelProxyExtensionFramework
class FirewallWhitelisterTest: QuickSpec {
    override class func spec() {
        describe("FirewallWhitelisterTest") {
            it("sets the effective group Id") {
                var whitelister = FirewallWhitelister(groupName: "foo")
                let mockUtils = MockProcessUtilities()
                whitelister.utils = mockUtils
                _ = whitelister.whitelist()
                expect(mockUtils.didCall("setEffectiveGroupID")).to(beTrue())
            }
        }
    }
}
