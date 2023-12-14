import Foundation
import NetworkExtension
import NIO

final class IOFlowLibNIO : IOFlowLib {
    let eventLoopGroup: MultiThreadedEventLoopGroup
    let interfaceAddress: String
    
    init(interfaceName: String) {
        self.interfaceAddress = getNetworkInterfaceIP(interfaceName: interfaceName)!
        // trying with just 1 thread for now, since we dont want to use too many resources on the user's machines.
        // SwiftNIO docs says it is still better to use MultiThreadedEventLoopGroup, even in the case of 1 thread used
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    deinit {
        try! eventLoopGroup.syncShutdownGracefully()
    }

    func handleTCPFlowIO(_ flow: NEAppProxyTCPFlow) {
    }

    func handleUDPFlowIO(_ flow: NEAppProxyUDPFlow) {
    }
}
