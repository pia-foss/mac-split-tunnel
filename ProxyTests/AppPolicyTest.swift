@testable import SplitTunnelProxy
import Quick
import Nimble

class AppPolicySpec: QuickSpec {
    override class func spec() {
        describe("AppPolicy") {
            context("when the VPN is connected with default route") {
                let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: ["com.apple.safari"], routeVpn: true, connected: true)
                let appPolicy = AppPolicy(vpnState: vpnState)

                it("should proxy apps in the bypass list") {
                    expect(appPolicy.policyFor("com.apple.curl")).to(equal(AppPolicy.Policy.proxy))
                }

                it("should ignore apps in the vpnOnly list") {
                    expect(appPolicy.policyFor("com.apple.safari")).to(equal(AppPolicy.Policy.ignore))
                }

                it("should ignore apps not in any list") {
                    expect(appPolicy.policyFor("com.apple.foo")).to(equal(AppPolicy.Policy.ignore))
                }
            }

            context("when the VPN is connected without default route") {
                let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: ["com.apple.safari"], routeVpn: false, connected: true)
                let appPolicy = AppPolicy(vpnState: vpnState)

                it("should proxy apps in the vpnOnly list") {
                    expect(appPolicy.policyFor("com.apple.safari")).to(equal(AppPolicy.Policy.proxy))
                }

                it("should ignore apps in the bypass list") {
                    expect(appPolicy.policyFor("com.apple.curl")).to(equal(AppPolicy.Policy.ignore))
                }

                it("should ignore apps not in any list") {
                    expect(appPolicy.policyFor("com.apple.foo")).to(equal(AppPolicy.Policy.ignore))
                }
            }

            context("when the VPN is disconnected") {
                let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: ["com.apple.safari"], routeVpn: true, connected: false)
                let appPolicy = AppPolicy(vpnState: vpnState)


                it("should block apps in the vpnOnly list") {
                    expect(appPolicy.policyFor("com.apple.safari")).to(equal(AppPolicy.Policy.block))
                }

                it("should ignore apps in the bypass list") {
                    expect(appPolicy.policyFor("com.apple.curl")).to(equal(AppPolicy.Policy.ignore))
                }

                it("should ignore apps not in any list") {
                    expect(appPolicy.policyFor("com.apple.foo")).to(equal(AppPolicy.Policy.ignore))
                }

            }

            context("when checking policy by app path") {
                let vpnState = VpnState(bypassApps: ["/usr/bin/curl"], vpnOnlyApps: ["/usr/bin/safari"], routeVpn: false, connected: true)
                let appPolicy = AppPolicy(vpnState: vpnState)

                it("should ignore apps in the bypass list when VPN is connected") {
                    expect(appPolicy.policyFor("/usr/bin/curl")).to(equal(AppPolicy.Policy.ignore))
                }

                it("should proxy apps in the vpnOnly list when connected") {
                    expect(appPolicy.policyFor("/usr/bin/safari")).to(equal(AppPolicy.Policy.proxy))
                }

                it("should ignore apps not in any list when VPN is connected") {
                    expect(appPolicy.policyFor("/usr/bin/foo")).to(equal(AppPolicy.Policy.ignore))
                }
            }
        }
    }
}
