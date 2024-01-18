//
//  MockLogger.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 18/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import Puppy

class MockLogger: LoggerProtocol, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    // Required by Logger
    public func initializeLogger(logLevel: String, logFile: String) -> Bool {
        record(args: [logLevel, logFile])
        return true
    }

    public func logLevelFromString(_ levelString: String) -> LogLevel {
        record(args: [levelString])
        return .debug
    }

    public func debug(_ message: String) { record(args: [message]) }
    public func info(_ message: String) { record(args: [message]) }
    public func warning(_ message: String) { record(args: [message]) }
    public func error(_ message: String) { record(args: [message]) }
}
