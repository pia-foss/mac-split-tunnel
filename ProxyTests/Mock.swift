//
//  Mock.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 12/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

// AnyObject constrains the protocol to class types
// This is necessary as record() is a mutating function
// which struct types do not (easily) allow
protocol Mock: AnyObject {
    var methodsCalled: Set<String> { get set }
}

// Default implementation
extension Mock {
    // Indicates whether a function was called
    func didCall(_ function: String) -> Bool {
        methodsCalled.contains(function)
    }

    // Records the calling of a function
    func record(_ function: String = #function) {
        methodsCalled.insert(function)
    }
}
