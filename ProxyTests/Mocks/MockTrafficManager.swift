//
//  MockTrafficManager.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 18/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

final class MockTrafficManager: TrafficManager, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    public func handleFlowIO(_ flow: Flow) {
        record(args: [flow])
    }
}
