import Foundation
import NetworkExtension

protocol IOFlowLib {
    func handleFlowIO(_ flow: NEAppProxyFlow)
}
