import Foundation
import NetworkExtension

protocol TrafficManager {
    func handleFlowIO(_ flow: NEAppProxyFlow)
}
