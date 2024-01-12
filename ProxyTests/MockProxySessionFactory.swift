//
//  MockProxySession.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 12/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

class MockProxySessionFactory: ProxySessionFactory, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []

    func create(flow: FlowTCP, config: SessionConfig, id: IDGenerator.ID) -> ProxySession {
        record("createTCP")
        return ProxySessionTCP(flow: flow, config: config, id: IDGenerator().nextID)
    }

    func create(flow: FlowUDP, config: SessionConfig, id: IDGenerator.ID) -> ProxySession {
        record("createUDP")
        return ProxySessionUDP(flow: flow, config: config, id: IDGenerator().nextID)
    }
}
