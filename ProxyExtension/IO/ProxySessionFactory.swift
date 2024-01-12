//
//  ProxySessionFactory.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 11/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NetworkExtension

protocol ProxySessionFactory {
    func create(flow: FlowTCP, config: SessionConfig, id: IDGenerator.ID) -> ProxySession
    func create(flow: FlowUDP, config: SessionConfig, id: IDGenerator.ID) -> ProxySession
}

final class DefaultProxySessionFactory: ProxySessionFactory {
    public func create(flow: FlowTCP, config: SessionConfig, id: IDGenerator.ID) -> ProxySession {
        return ProxySessionTCP(flow: flow, config: config, id: id)
    }

    public func create(flow: FlowUDP, config: SessionConfig, id: IDGenerator.ID) -> ProxySession {
        return ProxySessionUDP(flow: flow, config: config, id: id)
    }
}
