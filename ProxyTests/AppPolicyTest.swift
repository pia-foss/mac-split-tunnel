@testable import SplitTunnelProxy
import Quick
import Nimble

class AppPolicySpec: QuickSpec {
    override class func spec() {
        describe("AppPolicy") {
            context("when the VPN is connected with default route") {
                let appPolicy = AppPolicy(bypassApps: ["com.apple.curl"], vpnOnlyApps: ["com.apple.safari"], routeVpn: true, connected: true)

                it("should proxy apps in the bypass list") {
                    expect(appPolicy.policyFor(appId: "com.apple.curl")).to(equal(AppPolicy.Policy.proxy))
                }

                it("should ignore apps in the vpnOnly list") {
                    expect(appPolicy.policyFor(appId: "com.apple.safari")).to(equal(AppPolicy.Policy.ignore))
                }

                it("should ignore apps not in any list") {
                    expect(appPolicy.policyFor(appId: "com.apple.foo")).to(equal(AppPolicy.Policy.ignore))
                }
            }

            context("when the VPN is connected without default route") {
                let appPolicy = AppPolicy(bypassApps: ["com.apple.curl"], vpnOnlyApps: ["com.apple.safari"], routeVpn: false, connected: true)

                it("should proxy apps in the vpnOnly list") {
                    expect(appPolicy.policyFor(appId: "com.apple.safari")).to(equal(AppPolicy.Policy.proxy))
                }

                it("should ignore apps in the bypass list") {
                    expect(appPolicy.policyFor(appId: "com.apple.curl")).to(equal(AppPolicy.Policy.ignore))
                }

                it("should ignore apps not in any list") {
                    expect(appPolicy.policyFor(appId: "com.apple.foo")).to(equal(AppPolicy.Policy.ignore))
                }
            }

            context("when the VPN is disconnected") {
                let appPolicy = AppPolicy(bypassApps: ["com.apple.curl"], vpnOnlyApps: ["com.apple.safari"], routeVpn: true, connected: false)

                it("should block apps in the vpnOnly list") {
                    expect(appPolicy.policyFor(appId: "com.apple.safari")).to(equal(AppPolicy.Policy.block))
                }

                it("should ignore apps in the bypass list") {
                    expect(appPolicy.policyFor(appId: "com.apple.curl")).to(equal(AppPolicy.Policy.ignore))
                }

                it("should ignore apps not in any list") {
                    expect(appPolicy.policyFor(appId: "com.apple.foo")).to(equal(AppPolicy.Policy.ignore))
                }

            }

            context("when checking policy by app path") {
                let appPolicy = AppPolicy(bypassApps: ["/usr/bin/curl"], vpnOnlyApps: ["/usr/bin/safari"], routeVpn: false, connected: true)

                it("should ignore apps in the bypass list when VPN is connected") {
                    expect(appPolicy.policyFor(appPath: "/usr/bin/curl")).to(equal(AppPolicy.Policy.ignore))
                }

                it("should proxy apps in the vpnOnly list when connected") {
                    expect(appPolicy.policyFor(appPath: "/usr/bin/safari")).to(equal(AppPolicy.Policy.proxy))
                }

                it("should ignore apps not in any list when VPN is connected") {
                    expect(appPolicy.policyFor(appPath: "/usr/bin/foo")).to(equal(AppPolicy.Policy.ignore))
                }
            }
        }
    }
}
