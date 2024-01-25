//
//  MockNetworkInterface.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 25/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

final class MockNetworkInterface: NetworkInterfaceProtocol, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    // Required by NetworkInterface
    func ip4() -> String? {
        record()
        return "192.168.1.1"
    }
}
