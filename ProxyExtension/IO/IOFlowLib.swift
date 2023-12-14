import Foundation
import NetworkExtension

protocol IOFlowLib {
    func handleTCPFlowIO(_ flow: NEAppProxyTCPFlow)

    func handleUDPFlowIO(_ flow: NEAppProxyUDPFlow)
}
