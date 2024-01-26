//
//  NewFlowHandler.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 25/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NetworkExtension
import NIO

final class NewFlowHandler {
    let vpnState: VpnState

    var sessionConfig: SessionConfig!
    let proxySessionFactory: ProxySessionFactory
    var idGenerator: IDGenerator

    init(vpnState: VpnState,
         proxySessionFactory: ProxySessionFactory = DefaultProxySessionFactory(),
         config: SessionConfig? = nil) {
        self.vpnState = vpnState

        self.idGenerator = IDGenerator()
        self.sessionConfig = config
        self.proxySessionFactory = proxySessionFactory
    }

    private func startProxySession(flow: Flow) -> Bool {
        let appID = flow.sourceAppSigningIdentifier
        flow.openFlow { error in
            guard error == nil else {
                log(.error, "\(appID) \"\(error!.localizedDescription)\" in \(String(describing: flow.self)) open()")
                return
            }
            self.handleFlowIO(flow)
        }
        return true
    }

    // Fire off a proxy session for each new flow
    func handleFlowIO(_ flow: Flow) {
        let nextId = idGenerator.generate()
        if let tcpFlow = flow as? FlowTCP {
            let tcpSession = proxySessionFactory.create(flow: tcpFlow, config: sessionConfig, id: nextId)
            tcpSession.start()
        } else if let udpFlow = flow as? FlowUDP {
            let udpSession = proxySessionFactory.create(flow: udpFlow, config: sessionConfig, id: nextId)
            udpSession.start()
        }
    }

    public func handleNewFlow(_ flow: Flow) -> Bool {
        guard isFlowIPv4(flow) else {
            return false
        }

        switch FlowPolicy.policyFor(flow: flow, vpnState: vpnState) {
        case .proxy:
            return startProxySession(flow: flow)
        case .block:
            flow.closeReadAndWrite()
            // We return true to indicate to the OS we want to handle the flow, so the app is blocked.
            return true
        case .ignore:
            return false
        }
    }

    // Is the flow IPv4 ? (we only support IPv4 flows at present)
    private func isFlowIPv4(_ flow: Flow) -> Bool {
        if let flowTCP = flow as? FlowTCP {
            log(.debug, "The flow is TCP and flow.remoteEndpoint is: \(flowTCP.remoteEndpoint)")
            // Check if the address is an IPv6 address, and negate it. IPv6 addresses always contain a ":"
            // We can't do the opposite (such as just checking for "." for an IPv4 address) due to IPv4-mapped IPv6 addresses
            // which are IPv6 addresses but include IPv4 address notation.
            if let endpoint = flowTCP.remoteEndpoint as? NWHostEndpoint {
                // We have a valid NWHostEndpoint - let's see if it's IPv6
                if endpoint.hostname.contains(":") {
                    log(.debug, "TCP Flow is IPv6 - won't handle")
                    return false
                } else {
                    log(.debug, "TCP Flow is IPv4 - will handle")
                    return true
                }
            } else {
                log(.debug, "Found a TCP Flow, but cannot extract NWHostEndPoint - assuming IPv4")
                // We cannot know for sure, just assume it's IPv4
                return true
            }
        } else {
            log(.debug, "The flow is UDP, no remoteEndpoint data available. Assume IPv4")
            return true
        }
    }
}
