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
        if(vpnState.dnsFollowAppRules) {
            // TODO: Fetch these from vpnState. PIA-1942
            // These are the backed up original ISP DNS servers.
            let ispDnsServers: [String] = ["1.1.1.1"]
            // This will probably be just the PIA server we are connected to
            let piaDnsServers: [String] = ["8.8.8.8"]
            switch dnsPolicyFor(flow: flow, vpnState: vpnState) {
            case .proxyToPhysical:
                return startProxySession(flow: flow, vpnState: vpnState, dnsServers: ispDnsServers)
            case .proxyToVpn:
                return startProxySession(flow: flow, vpnState: vpnState, dnsServers: piaDnsServers)
            case .block:
                return false
            }
        } else {
            // currently not handling any DNS requests if mode is VPN DNS Only
            return false
        }
    }

    // The DNS policy we should apply to an app
    enum DnsPolicy {
        case proxyToPhysical, proxyToVpn, block
    }

    // The policy logic is easier compared to the transparent proxy one.
    // bypass mode: always proxy to physical.
    // only vpn mode: always proxy to vpn. Block if the vpn is disconnected
    // unspecified mode: always proxy to the default route interface
    private func dnsPolicyFor(flow: Flow, vpnState: VpnState) -> DnsPolicy {
        let mode = FlowPolicy.modeFor(flow: flow, vpnState: vpnState)
        if(mode == AppPolicy.Mode.bypass) {
            return .proxyToPhysical
        } else if(mode == AppPolicy.Mode.vpnOnly) {
            if(vpnState.isConnected) {
                return .proxyToVpn
            } else {
                return .block
            }
        } else { // unspecified case, it means the app has no specific settings
            if(vpnState.routeVpn) { // normal ST mode, vpn has the default route
                return .proxyToVpn
            } else {
                return .proxyToPhysical
            }
        }
    }

    // Instead of using the original endpoint as in the transparent proxy,
    // we force a specific server for the DNS request, based on
    private func startProxySession(flow: Flow, vpnState: VpnState, dnsServers: [String]) -> Bool {
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
