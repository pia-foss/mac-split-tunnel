import Quick
import Nimble
import NetworkExtension

@testable import SplitTunnelProxyExtensionFramework
class FlowPolicySpec: QuickSpec {
    override class func spec() {
        describe("FlowPolicySpec") {
            context("bypass flows when disconnected") {
                let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: ["com.apple.safari"], routeVpn: true, isConnected: false)

                it("ignores Ipv6 bypass flows") {
                    let mockFlow = MockFlowTCP()
                    mockFlow.remoteEndpoint = NWHostEndpoint(hostname: "2b17:fb8c:8b61:8f15:28b7:d783:0448:81a3", port: "1337")
                    mockFlow.sourceAppSigningIdentifier = "com.apple.curl"

                    let policy = FlowPolicy.policyFor(flow: mockFlow, vpnState: vpnState)

                    expect(policy).to(equal(AppPolicy.Policy.ignore))
                }

                it("ignores Ipv4 bypass flows") {
                    let mockFlow = MockFlowTCP()
                    mockFlow.remoteEndpoint = NWHostEndpoint(hostname: "1.1.1.1", port: "1337")
                    mockFlow.sourceAppSigningIdentifier = "com.apple.curl"

                    let policy = FlowPolicy.policyFor(flow: mockFlow, vpnState: vpnState)

                    expect(policy).to(equal(AppPolicy.Policy.ignore))
                }
            }

            context("bypass flows when connected") {
                let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: ["com.apple.safari"], routeVpn: true, isConnected: true)

                it("proxies Ipv6 bypass flows") {
                    let mockFlow = MockFlowTCP()
                    mockFlow.remoteEndpoint = NWHostEndpoint(hostname: "2b17:fb8c:8b61:8f15:28b7:d783:0448:81a3", port: "1337")
                    mockFlow.sourceAppSigningIdentifier = "com.apple.curl"

                    let policy = FlowPolicy.policyFor(flow: mockFlow, vpnState: vpnState)

                    expect(policy).to(equal(AppPolicy.Policy.proxy))
                }

                it("proxies Ipv4 bypass flows") {
                    let mockFlow = MockFlowTCP()
                    mockFlow.remoteEndpoint = NWHostEndpoint(hostname: "1.1.1.1", port: "1337")
                    mockFlow.sourceAppSigningIdentifier = "com.apple.curl"

                    let policy = FlowPolicy.policyFor(flow: mockFlow, vpnState: vpnState)

                    expect(policy).to(equal(AppPolicy.Policy.proxy))
                }
            }

            context("vpnOnly flows when disconnected") {
                let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: ["com.apple.safari"], routeVpn: false, isConnected: false)

                it("blocks Ipv4 vpnOnly flows") {
                    let mockFlow = MockFlowTCP()
                    mockFlow.remoteEndpoint = NWHostEndpoint(hostname: "1.1.1.1", port: "1337")
                    mockFlow.sourceAppSigningIdentifier = "com.apple.safari"

                    let policy = FlowPolicy.policyFor(flow: mockFlow, vpnState: vpnState)

                    expect(policy).to(equal(AppPolicy.Policy.block))
                }

                it("blocks Ipv6 vpnOnly flows") {
                    let mockFlow = MockFlowTCP()
                    mockFlow.remoteEndpoint = NWHostEndpoint(hostname: "2b17:fb8c:8b61:8f15:28b7:d783:0448:81a3", port: "1337")
                    mockFlow.sourceAppSigningIdentifier = "com.apple.safari"

                    let policy = FlowPolicy.policyFor(flow: mockFlow, vpnState: vpnState)

                    expect(policy).to(equal(AppPolicy.Policy.block))
                }
            }

            context("vpnOnly flows when connected") {
                let vpnState = VpnState(bypassApps: ["com.apple.curl"], vpnOnlyApps: ["com.apple.safari"], routeVpn: false, isConnected: true)

                it("proxies Ipv4 vpnOnly flows") {
                    let mockFlow = MockFlowTCP()
                    mockFlow.remoteEndpoint = NWHostEndpoint(hostname: "1.1.1.1", port: "1337")
                    mockFlow.sourceAppSigningIdentifier = "com.apple.safari"

                    let policy = FlowPolicy.policyFor(flow: mockFlow, vpnState: vpnState)

                    expect(policy).to(equal(AppPolicy.Policy.proxy))
                }

                it("blocks Ipv6 vpnOnly flows") {
                    let mockFlow = MockFlowTCP()
                    mockFlow.remoteEndpoint = NWHostEndpoint(hostname: "2b17:fb8c:8b61:8f15:28b7:d783:0448:81a3", port: "1337")
                    mockFlow.sourceAppSigningIdentifier = "com.apple.safari"

                    let policy = FlowPolicy.policyFor(flow: mockFlow, vpnState: vpnState)

                    expect(policy).to(equal(AppPolicy.Policy.block))
                }
            }
        }
    }
}
