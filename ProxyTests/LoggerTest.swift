//
//  LoggerTest.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 19/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Quick
import Nimble

@testable import SplitTunnelProxyExtensionFramework
class LoggerTest: QuickSpec {
    override class func spec() {
        describe("LoggerTest") {
            context("log()") {
                it("delegates log(.debug, ...) to Logger.instance") {
                    let mockLogger = MockLogger()
                    Logger.instance = mockLogger
                    log(.debug, "hello world")
                    expect(mockLogger.didCall("debug")).to(equal(true))
                }

                it("delegates log(.info, ...) to Logger.instance") {
                    let mockLogger = MockLogger()
                    Logger.instance = mockLogger
                    log(.info, "hello world")
                    expect(mockLogger.didCall("info")).to(equal(true))
                }

                it("delegates log(.warning, ...) to Logger.instance") {
                    let mockLogger = MockLogger()
                    Logger.instance = mockLogger
                    log(.warning, "hello world")
                    expect(mockLogger.didCall("warning")).to(equal(true))
                }

                it("delegates log(.error, ...) to Logger.instance") {
                    let mockLogger = MockLogger()
                    Logger.instance = mockLogger
                    log(.error, "hello world")
                    expect(mockLogger.didCall("error")).to(equal(true))
                }

                it("delegates an unsupported log level to Logger.instance.info") {
                    let mockLogger = MockLogger()
                    Logger.instance = mockLogger
                    log(.critical, "hello world")
                    expect(mockLogger.didCall("info")).to(equal(true))
                }
            }
        }
    }
}
