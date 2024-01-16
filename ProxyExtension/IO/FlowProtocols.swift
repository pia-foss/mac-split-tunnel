//
//  FlowProtocol.swift
//  SplitTunnelProxyExtension
//
//  Created by John Mair on 12/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NetworkExtension

// Flow base protocol we use in place of NEAppProxyFlow, it also provides shortcuts for common functions.
protocol Flow {
    // Shortcut to close both read and write ends of a flow
    func closeReadAndWrite()
    // Shortcut to open a flow (we don't call it 'open' as this name is too general and may
    // cause conflicts in the future)
    func openFlow(completionHandler: @escaping (Error?) -> Void)
    // A shortcut to get to the signing identifier
    var sourceAppSigningIdentifier: String { get }
    // If the flow was created by passing a hostname to a "connect by name" API such as NSURLSession or
    // Network.framework, this property is set to the remote hostname
    var remoteHostname: String? { get }
    // Shortcut to the audit token
    var sourceAppAuditToken: Data? { get }
}

// FlowTCP and FlowUDP protocols abstract the relevant parts of NEAppProxyTCPFlow
// and NEAppProxyUDPFlow for increased flexibility and improved testability.
protocol FlowTCP: Flow {
    var remoteEndpoint: NWEndpoint { get }
    func readData(completionHandler: @escaping (Data?, Error?) -> Void)
    func write(_ data: Data, withCompletionHandler completionHandler: @escaping (Error?) -> Void)
}

protocol FlowUDP: Flow {
    func readDatagrams(completionHandler: @escaping ([Data]?, [NWEndpoint]?, Error?) -> Void)
    func writeDatagrams(_ datagrams: [Data], sentBy remoteEndpoints: [NWEndpoint], completionHandler: @escaping (Error?) -> Void)
}
