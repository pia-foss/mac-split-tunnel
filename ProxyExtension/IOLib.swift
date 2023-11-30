import Foundation
import NetworkExtension

protocol IOLib {
    func handleReadAndWrite(_ tProtocol: TransportProtocol, _ flow: NEAppProxyFlow, _ socket: Socket)
}
