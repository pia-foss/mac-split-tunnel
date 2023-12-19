import Foundation
import NetworkExtension
import NIO

protocol IODictionary {
    func addPair(flow: NEAppProxyFlow, channel: Channel)

    func removePair(flow: NEAppProxyFlow)

    func getChannel(flow: NEAppProxyFlow)  -> Channel?
    
    func getFlow(channel: Channel) -> NEAppProxyFlow?
}
