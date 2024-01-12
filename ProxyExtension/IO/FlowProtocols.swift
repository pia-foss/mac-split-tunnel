//
//  FlowProtocol.swift
//  SplitTunnelProxyExtension
//
//  Created by John Mair on 12/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NetworkExtension

// A few extensions for convenience
protocol Flow {
    // Shortcut to close both read and write ends of a flow
    func closeReadAndWrite()
    // A shortcut to get to the signing identifier
    var sourceAppSigningIdentifier: String { get }
}

protocol FlowTCP: Flow {
    var remoteEndpoint: NWEndpoint { get }
    func readData(completionHandler: @escaping (Data?, Error?) -> Void)
    func write(_ data: Data, withCompletionHandler completionHandler: @escaping (Error?) -> Void)
}

protocol FlowUDP: Flow {
    func readDatagrams(completionHandler: @escaping ([Data]?, [NWEndpoint]?, Error?) -> Void)
    func writeDatagrams(_ datagrams: [Data], sentBy remoteEndpoints: [NWEndpoint], completionHandler: @escaping (Error?) -> Void)
}
