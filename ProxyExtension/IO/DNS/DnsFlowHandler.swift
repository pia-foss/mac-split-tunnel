import Foundation
import NetworkExtension
import NIO

// Responsible for handling DNS flows, both new flows and pre-existing
final class DnsFlowHandler: FlowHandlerProtocol {
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
        // We need to handle two modes here:
        // - Follow App Rules
        // - VPN DNS Only
        // assume for now that Name Servers is set to Follow App Rules
        // if(name server is follow app rules)
        //     if(app is bypass app)
        //         proxy to physical
        //     else
        //         if(vpn is disconnected)
        //             block
        //         else
        //             proxy to vpn //using current DNS settings
        return startProxySession(flow: flow, vpnState: vpnState)
    }

    private func startProxySession(flow: Flow, vpnState: VpnState) -> Bool {
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
