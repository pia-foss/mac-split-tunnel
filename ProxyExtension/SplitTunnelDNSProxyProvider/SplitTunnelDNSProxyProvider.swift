import Foundation
import NetworkExtension

final class SplitTunnelDNSProxyProvider : NEDNSProxyProvider {
    override init() {
        super.init()
    }

    override func startProxy(options:[String: Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }

    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    //  Be aware that by returning false in NEDNSProxyProvider handleNewFlow(),
    //  the flow is discarded and the connection is closed
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        return false
    }
}
