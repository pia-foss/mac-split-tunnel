//
//  MockProxyOptionsFactory.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 18/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

class MockProxyOptionsFactory: ProxyOptionsFactoryProtocol, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    func create(options: [String : Any]?) -> ProxyOptions? {
        record(args: [options as Any])

        // Delegate to the original implementation - this is because when mocking this particular class
        // as part of testing another class, a valid result may be relied on
        return ProxyOptionsFactory().create(options: options)
    }
}
