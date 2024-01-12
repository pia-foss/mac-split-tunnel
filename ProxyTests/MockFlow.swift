//
//  MockFlow.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 12/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NetworkExtension

class MockFlowTCP: FlowTCP, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    // FlowTCP
    func closeReadAndWrite() {}
    var sourceAppSigningIdentifier: String { get {"quinn"} }
    var remoteEndpoint: NWEndpoint {
        get {
            return NWHostEndpoint(hostname: "127.0.0.1", port: "1337")
        }
    }

    func readData(completionHandler: @escaping (Data?, Error?) -> Void) { record() }
    func write(_ data: Data, withCompletionHandler completionHandler: @escaping (Error?) -> Void) { record() }
}

class MockFlowUDP: FlowUDP, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    // FlowUDP
    func closeReadAndWrite() {}
    var sourceAppSigningIdentifier: String { get {"quinn"} }
    var remoteEndpoint: NWEndpoint {
        get {
            return NWHostEndpoint(hostname: "127.0.0.1", port: "1337")
        }
    }

    func readDatagrams(completionHandler: @escaping ([Data]?, [NWEndpoint]?, Error?) -> Void) { record() }
    func writeDatagrams(_ datagrams: [Data], sentBy remoteEndpoints: [NWEndpoint], completionHandler: @escaping (Error?) -> Void) { record() }
}
