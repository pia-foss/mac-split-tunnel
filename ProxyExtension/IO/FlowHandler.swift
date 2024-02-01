import Foundation
import NetworkExtension
import NIO

// Core config required to start a new proxy session
// * The bindIp - which we use to bind ipv4 sockets to change default routing behaviour
// * The eventLoopGroup - required to setup the NIO Inbound Handlers
struct SessionConfig {
    var bindIp: String { interface.ip4()! }
    let interface: NetworkInterfaceProtocol
    // We need to make this optional so that we can
    // leave it nil in tests - tests do not use an EventLoopGroup
    let eventLoopGroup: MultiThreadedEventLoopGroup!
}

protocol FlowHandlerProtocol {
    func handleNewFlow(_ flow: Flow, vpnState: VpnState) -> Bool
}

// Responsible for handling flows, both new flows and pre-existing
final class FlowHandler: FlowHandlerProtocol {
    let eventLoopGroup: MultiThreadedEventLoopGroup
    var idGenerator: IDGenerator

    // explicitly set this for tests
    var proxySessionFactory: ProxySessionFactory

    init() {
        self.idGenerator = IDGenerator()
        self.proxySessionFactory = DefaultProxySessionFactory()
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    deinit {
        try! eventLoopGroup.syncShutdownGracefully()
    }

    public func handleNewFlow(_ flow: Flow, vpnState: VpnState) -> Bool {
        guard isFlowIPv4(flow) else {
            return false
        }

        let sessionConfig = SessionConfig(interface: NetworkInterface(interfaceName: vpnState.networkInterface),
                                          eventLoopGroup: eventLoopGroup)

        switch FlowPolicy.policyFor(flow: flow, vpnState: vpnState) {
        case .proxy:
            return startProxySession(flow: flow, sessionConfig: sessionConfig)
        case .block:
            log(.info, "blocking a vpnOnly flow from \(flow.sourceAppSigningIdentifier)")
            flow.closeReadAndWrite()
            // We return true to indicate to the OS we want to handle the flow, so the app is blocked.
            return true
        case .ignore:
            return false
        }
    }

    private func startProxySession(flow: Flow, sessionConfig: SessionConfig) -> Bool {
        flow.openFlow { error in
            guard error == nil else {
                log(.error, "\(flow.sourceAppSigningIdentifier) \"\(error!.localizedDescription)\" in \(String(describing: flow.self)) open()")
                return
            }
            self.handleFlowIO(flow, sessionConfig: sessionConfig)
        }
        return true
    }

    // Fire off a proxy session for each new flow
    func handleFlowIO(_ flow: Flow, sessionConfig: SessionConfig) {
        let nextId = idGenerator.generate()
        if let tcpFlow = flow as? FlowTCP {
            let tcpSession = proxySessionFactory.createTCP(flow: tcpFlow, config: sessionConfig, id: nextId)
            tcpSession.start()
        } else if let udpFlow = flow as? FlowUDP {
            let udpSession = proxySessionFactory.createUDP(flow: udpFlow, config: sessionConfig, id: nextId)
            udpSession.start()
        }
    }

    // Is the flow IPv4 ? (we only support IPv4 flows at present)
    private func isFlowIPv4(_ flow: Flow) -> Bool {
        if let flowTCP = flow as? FlowTCP {
            // Check if the address is an IPv6 address, and negate it. IPv6 addresses always contain a ":"
            // We can't do the opposite (such as just checking for "." for an IPv4 address) due to IPv4-mapped IPv6 addresses
            // which are IPv6 addresses but include IPv4 address notation.
            if let endpoint = flowTCP.remoteEndpoint as? NWHostEndpoint {
                // We have a valid NWHostEndpoint - let's see if it's IPv6
                if endpoint.hostname.contains(":") {
                    return false
                } else {
                    return true
                }
            } else {
                // We cannot know for sure, just assume it's IPv4
                return true
            }
        } else {
            return true
        }
    }
}
