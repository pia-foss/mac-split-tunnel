//
//  MockNetworkInterface.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 25/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

@testable import SplitTunnelProxyExtensionFramework
final class MockNetworkInterface: NetworkInterfaceProtocol, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    let ip: String

    init(ip: String = "192.168.100.1") {
        self.ip = ip
    }

    // Required by NetworkInterface
    var interfaceName = "en0"

    func ip4() -> String? {
        record()
        return ip
    }
}
