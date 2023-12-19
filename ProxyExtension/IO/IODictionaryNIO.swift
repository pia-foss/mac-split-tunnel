import Foundation
import NetworkExtension
import NIO

final class IODictionaryNIO : IODictionary {
    // Global dictionary for storing (NEAppProxyFlow, Channel) pairs
    var flowToChannelMap: Dictionary<NEAppProxyFlow, Channel>
    // We need to use ObjectIdentifier because Channel is not hashable:
    // "Type 'any Channel' does not conform to protocol 'Hashable'"
    var channelToFlowMap: Dictionary<ObjectIdentifier, NEAppProxyFlow>
    // The queue ensures that access to the dictionary are thread-safe.
    // We might want to remove the label, or make it dynamic based on the extension bundle ID.
    // It has no functional impact, it is useful just for debugging / tracing
    let mapsQueue: DispatchQueue
    
    init(label: String) {
        flowToChannelMap = [NEAppProxyFlow: Channel]()
        channelToFlowMap = [ObjectIdentifier: NEAppProxyFlow]()
        mapsQueue = DispatchQueue(
            label: label,
            attributes: .concurrent)
    }

    // This function adds a new pair to the dictionary.
    // The barrier flag ensures that add and remove operations are not executed concurrently
    // with any other read or write operations
    func add(flow: NEAppProxyFlow, channel: Channel) {
        mapsQueue.async(flags: .barrier) {
            self.flowToChannelMap[flow] = channel
            self.channelToFlowMap[ObjectIdentifier(channel)] = flow
        }
    }

    func remove(flow: NEAppProxyFlow) {
        mapsQueue.async(flags: .barrier) {
            if let channel = self.flowToChannelMap[flow] {
                self.channelToFlowMap.removeValue(forKey: ObjectIdentifier(channel))
                self.flowToChannelMap.removeValue(forKey: flow)
            }
        }
    }
    
    func remove(channel: Channel) {
        mapsQueue.async(flags: .barrier) {
            if let flow = self.channelToFlowMap[ObjectIdentifier(channel)] {
                self.channelToFlowMap.removeValue(forKey: ObjectIdentifier(channel))
                self.flowToChannelMap.removeValue(forKey: flow)
            }
        }
    }

    // These functions just read, so they can be executed on multiple threads
    func getChannel(flow: NEAppProxyFlow) -> Channel? {
        return mapsQueue.sync {
            return flowToChannelMap[flow]
        }
    }
    
    func getFlow(channel: Channel) -> NEAppProxyFlow? {
        return mapsQueue.sync {
            return channelToFlowMap[ObjectIdentifier(channel)]
        }
    }
}
