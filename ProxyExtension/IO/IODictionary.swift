import Foundation
import NetworkExtension
import NIO

protocol IODictionary {
    func add(flow: NEAppProxyFlow, channel: Channel)

    func remove(flow: NEAppProxyFlow)
    
    func remove(channel: Channel)

    func getChannel(flow: NEAppProxyFlow)  -> Channel?
    
    func getFlow(channel: Channel) -> NEAppProxyFlow?
}
