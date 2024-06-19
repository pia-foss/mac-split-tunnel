import Foundation
import NetworkExtension
import NIO

// Core config required to start a new proxy session
// * The bindIp - which we use to bind ipv4 sockets to change default routing behaviour
// * The eventLoopGroup - required to setup the NIO Inbound Handlers
struct SessionConfig {
    let bindIp: String
    // We need to make this optional so that we can
    // leave it nil in tests - tests do not use an EventLoopGroup
    let eventLoopGroup: MultiThreadedEventLoopGroup!
}

protocol FlowHandlerProtocol {
    func handleNewFlow(_ flow: Flow, vpnState: VpnState) -> Bool
    func startProxySession(flow: Flow, vpnState: VpnState) -> Bool
}

// Responsible for handling flows, both new flows and pre-existing
final class FlowHandler: FlowHandlerProtocol {
    let eventLoopGroup: MultiThreadedEventLoopGroup
    var idGenerator: IDGenerator

    // explicitly set these for tests
    var proxySessionFactory: ProxySessionFactory
    var networkInterfaceFactory: NetworkInterfaceFactory

    init() {
        self.idGenerator = IDGenerator()
        self.proxySessionFactory = DefaultProxySessionFactory()
        self.networkInterfaceFactory = DefaultNetworkInterfaceFactory()
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    deinit {
        try! eventLoopGroup.syncShutdownGracefully()
    }

    public func handleNewFlow(_ flow: Flow, vpnState: VpnState) -> Bool {
        switch FlowPolicy.policyFor(flow: flow, vpnState: vpnState) {
        case .proxy:
            return startProxySession(flow: flow, vpnState: vpnState)
        case .block:
            log(.info, "blocking a vpnOnly flow from \(flow.sourceAppSigningIdentifier)")
            flow.closeReadAndWrite()
            // We return true to indicate to the OS we want to handle the flow, so the app is blocked.
            return true
        case .ignore:
            return false
        }
    }

    // temporarly public
    public func startProxySession(flow: Flow, vpnState: VpnState) -> Bool {
        let interface = networkInterfaceFactory.create(interfaceName: vpnState.bindInterface)

        // Verify we have a valid bindIp - if not, trace it and ignore the flow
        guard let bindIp = interface.ip4() else {
            log(.error, "Cannot find ipv4 ip for interface: \(interface.interfaceName)" +
                " - ignoring matched flow: \(flow.sourceAppSigningIdentifier)")
            // TODO: Should block the flow instead - especially for vpnOnly flows?
            return false
        }

        let sessionConfig = SessionConfig(bindIp: bindIp, eventLoopGroup: eventLoopGroup)

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
}
