import Foundation

@testable import SplitTunnelProxyExtensionFramework
final class MockFlowHandler: FlowHandlerProtocol, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    // Required by FlowHandlerProtocol
    func handleNewFlow(_ flow: Flow, vpnState: VpnState) -> Bool {
        record(args: [flow, vpnState])
        return true
    }
    
    func startProxySession(flow: Flow, vpnState: VpnState) -> Bool {
        record(args: [flow, vpnState])
        return true
    }
}
