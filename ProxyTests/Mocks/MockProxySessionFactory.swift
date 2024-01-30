//
//  MockProxySession.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 12/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

// Mocks a ProxySessionFactory - for use in tests
@testable import SplitTunnelProxyExtensionFramework
final class MockProxySessionFactory: ProxySessionFactory, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    func createTCP(flow: FlowTCP, config: SessionConfig, id: IDGenerator.ID) -> ProxySession {
        record(args: [flow, config, id])
        return MockProxySession()
    }

    func createUDP(flow: FlowUDP, config: SessionConfig, id: IDGenerator.ID) -> ProxySession {
        record(args: [flow, config, id])
        return MockProxySession()
    }
}
