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
    func createTCP(flow: NEAppProxyTCPFlow, config: SessionConfig, id: IDGenerator.ID) -> ProxySessionTCP
    func createUDP(flow: NEAppProxyUDPFlow, config: SessionConfig, id: IDGenerator.ID) -> ProxySessionUDP
}

final class DefaultProxySessionFactory: ProxySessionFactory {
    public func createTCP(flow: NEAppProxyTCPFlow, config: SessionConfig, id: IDGenerator.ID) -> ProxySessionTCP {
        return ProxySessionTCP(flow: flow, config: config, id: id)
    }

    public func createUDP(flow: NEAppProxyUDPFlow, config: SessionConfig, id: IDGenerator.ID) -> ProxySessionUDP {
        return ProxySessionUDP(flow: flow, config: config, id: id)
    }
}
