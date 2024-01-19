//
//  MockFlow.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 12/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NetworkExtension

// Mocks a FlowTCP for use in tests
final class MockFlowTCP: FlowTCP, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    let data: Data?
    let flowError: Error?

    init(data: Data? = nil, flowError: NSError? = nil) {
        self.data = data
        self.flowError = flowError
    }

    // Required by Flow
    func closeReadAndWrite() { record() }
    func openFlow(completionHandler: @escaping (Error?) -> Void) { record(args: [completionHandler]) 
        completionHandler(nil)
    }
    public var sourceAppSigningIdentifier: String = "quinn"
    public var remoteHostname: String? = nil
    public var sourceAppAuditToken: Data? = nil

    // Required by FlowTCP
    var remoteEndpoint: NWEndpoint { NWHostEndpoint(hostname: "8.8.8.8", port: "1337") }

    // Reads from our flow
    // Unlike the real readData on NEAppProxyTCPFlow this does not dispatch the
    // completion handler to another thread so we must be careful about how we
    // use it to avoid infinite recursion.
    func readData(completionHandler: @escaping (Data?, Error?) -> Void) {
        record(args: [completionHandler])
        completionHandler(data, flowError)
    }

    // Writes to our flow
    func write(_ data: Data, withCompletionHandler completionHandler: @escaping (Error?) -> Void) {
        record(args: [data, completionHandler])
        completionHandler(flowError)
    }
}

// Mocks a FlowUDP for use in tests
final class MockFlowUDP: FlowUDP, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    let data: [Data]?
    let endpoints: [NWEndpoint]?
    let flowError: Error?

    init(data: [Data]? = nil, endpoints: [NWEndpoint]? = nil, flowError: NSError? = nil) {
        self.data = data
        self.endpoints = endpoints
        self.flowError = flowError
    }

    // Required by Flow
    func closeReadAndWrite() { record() }
    func openFlow(completionHandler: @escaping (Error?) -> Void) { record(args: [completionHandler])
        completionHandler(nil)
    }
    public var sourceAppSigningIdentifier: String = "quinn"
    public var remoteHostname: String? = nil
    public var sourceAppAuditToken: Data? = nil

    // Required by FlowUDP
    func readDatagrams(completionHandler: @escaping ([Data]?, [NWEndpoint]?, Error?) -> Void) {
        record(args: [completionHandler])
        completionHandler(data, endpoints, flowError)
    }

    func writeDatagrams(_ datagrams: [Data], sentBy remoteEndpoints: [NWEndpoint], completionHandler: @escaping (Error?) -> Void) {
        record(args: [datagrams, remoteEndpoints, completionHandler])
    }
}
