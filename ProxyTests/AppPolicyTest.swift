import Quick
import Nimble

@testable import SplitTunnelProxyExtensionFramework
class AppPolicySpec: QuickSpec {
    override class func spec() {
        describe("AppPolicy") {
            context("when the VPN is connected with default route") {
                let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: ["com.apple.safari"], routeVpn: true, isConnected: true)
                let appPolicy = AppPolicy(vpnState: vpnState)

                it("should proxy apps in the bypass list") {
                    expect(appPolicy.policyFor("com.apple.curl")).to(equal(AppPolicy.Policy.proxy))

                    // Case is irrelevant
                    expect(appPolicy.policyFor("coM.appLe.Curl")).to(equal(AppPolicy.Policy.proxy))
                    expect(appPolicy.modeFor("coM.appLe.Curl")).to(equal(AppPolicy.Mode.bypass))
                }

                it("should ignore apps in the vpnOnly list") {
                    expect(appPolicy.policyFor("com.apple.safari")).to(equal(AppPolicy.Policy.ignore))

                    // Case is irrelevant
                    expect(appPolicy.policyFor("coM.appLe.SAfari")).to(equal(AppPolicy.Policy.ignore))
                    expect(appPolicy.modeFor("coM.appLe.SAfari")).to(equal(AppPolicy.Mode.vpnOnly))
                }

                it("should ignore apps not in any list") {
                    expect(appPolicy.policyFor("com.apple.foo")).to(equal(AppPolicy.Policy.ignore))

                    // Case is irrelevant
                    expect(appPolicy.policyFor("COM.APPLE.FOO")).to(equal(AppPolicy.Policy.ignore))
                    expect(appPolicy.modeFor("COM.APPLE.FOO")).to(equal(AppPolicy.Mode.unspecified))
                }

                it("should include apps that share a bundle id root with one in the bypass list") {
                    expect(appPolicy.policyFor("com.apple.curl.helper")).to(equal(AppPolicy.Policy.proxy))
                    expect(appPolicy.modeFor("com.apple.curl.helper")).to(equal(AppPolicy.Mode.bypass))
                }

                it("should include apps containing `-` that are prefixed by an app from the bypass list") {
                    expect(appPolicy.policyFor("com.apple.curl.curl-helper")).to(equal(AppPolicy.Policy.proxy))
                    expect(appPolicy.modeFor("com.apple.curl.curl-helper")).to(equal(AppPolicy.Mode.bypass))
                }
            }

            context("when the VPN is connected without default route") {
                let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: ["com.apple.safari"], routeVpn: false, isConnected: true)
                let appPolicy = AppPolicy(vpnState: vpnState)

                it("should proxy apps in the vpnOnly list") {
                    expect(appPolicy.policyFor("com.apple.safari")).to(equal(AppPolicy.Policy.proxy))
                    expect(appPolicy.modeFor("com.apple.safari")).to(equal(AppPolicy.Mode.vpnOnly))
                }

                it("should ignore apps in the bypass list") {
                    expect(appPolicy.policyFor("com.apple.curl")).to(equal(AppPolicy.Policy.ignore))
                    expect(appPolicy.modeFor("com.apple.curl")).to(equal(AppPolicy.Mode.bypass))
                }

                it("should ignore apps not in any list") {
                    expect(appPolicy.policyFor("com.apple.foo")).to(equal(AppPolicy.Policy.ignore))
                    expect(appPolicy.modeFor("com.apple.foo")).to(equal(AppPolicy.Mode.unspecified))
                }
            }

            context("when the VPN is disconnected") {
                let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: ["com.apple.safari"], routeVpn: true, isConnected: false)
                let appPolicy = AppPolicy(vpnState: vpnState)


                it("should block apps in the vpnOnly list") {
                    expect(appPolicy.policyFor("com.apple.safari")).to(equal(AppPolicy.Policy.block))
                    expect(appPolicy.modeFor("com.apple.safari")).to(equal(AppPolicy.Mode.vpnOnly))
                }

                it("should block apps if they share a bundle id root with one in the vpnOnly list") {
                    expect(appPolicy.policyFor("com.apple.safari.foo.bar")).to(equal(AppPolicy.Policy.block))
                    expect(appPolicy.modeFor("com.apple.safari.foo.bar")).to(equal(AppPolicy.Mode.vpnOnly))
                }

                it("should ignore apps in the bypass list") {
                    expect(appPolicy.policyFor("com.apple.curl")).to(equal(AppPolicy.Policy.ignore))
                    expect(appPolicy.modeFor("com.apple.curl")).to(equal(AppPolicy.Mode.bypass))
                }

                it("should ignore apps not in any list") {
                    expect(appPolicy.policyFor("com.apple.foo")).to(equal(AppPolicy.Policy.ignore))
                    expect(appPolicy.modeFor("com.apple.foo")).to(equal(AppPolicy.Mode.unspecified))
                }
            }

            context("when VpnState has mixed case app descriptors") {
                let vpnState = VpnState(bypassApps: ["com.FOO.bar"], vpnOnlyApps: ["com.BAR.foo"], routeVpn: true, isConnected: true)
                let appPolicy = AppPolicy(vpnState: vpnState)

                it("should proxy irrespective of descriptor case") {
                    expect(appPolicy.policyFor("com.foo.bar")).to(equal(AppPolicy.Policy.proxy))
                    expect(appPolicy.modeFor("com.foo.bar")).to(equal(AppPolicy.Mode.bypass))
                }

                it("should ignore irrespective of descriptor case") {
                    expect(appPolicy.policyFor("com.bar.foo")).to(equal(AppPolicy.Policy.ignore))
                    expect(appPolicy.modeFor("com.bar.foo")).to(equal(AppPolicy.Mode.vpnOnly))
                }
            }

            context("when checking policy by app path") {
                let vpnState = VpnState(bypassApps: ["/usr/bin/curl"], vpnOnlyApps: ["/usr/bin/safari"], routeVpn: false, isConnected: true)
                let appPolicy = AppPolicy(vpnState: vpnState)

                it("should ignore apps in the bypass list when VPN is connected") {
                    expect(appPolicy.policyFor("/usr/bin/curl")).to(equal(AppPolicy.Policy.ignore))
                    expect(appPolicy.modeFor("/usr/bin/curl")).to(equal(AppPolicy.Mode.bypass))
                }

                it("should proxy apps in the vpnOnly list when connected") {
                    expect(appPolicy.policyFor("/usr/bin/safari")).to(equal(AppPolicy.Policy.proxy))
                    expect(appPolicy.modeFor("/usr/bin/safari")).to(equal(AppPolicy.Mode.vpnOnly))
                }

                it("should ignore apps not in any list when VPN is connected") {
                    expect(appPolicy.policyFor("/usr/bin/foo")).to(equal(AppPolicy.Policy.ignore))
                }

                it("should ignore apps that are prefixed by an app from the bypass list") {
                    expect(appPolicy.policyFor("/usr/bin/curl/helper")).to(equal(AppPolicy.Policy.ignore))
                }
            }
        }
    }
}
