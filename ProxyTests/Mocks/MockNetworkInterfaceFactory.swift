//
//  MockNetworkInterfaceFactory.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 05/03/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

// Mocks a NetworkInterfaceFactory - for use in tests
@testable import SplitTunnelProxyExtensionFramework
final class MockNetworkInterfaceFactory: NetworkInterfaceFactory, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    func create(interfaceName: String) -> NetworkInterfaceProtocol {
        record(args: [interfaceName])
        return MockNetworkInterface()
    }
}
