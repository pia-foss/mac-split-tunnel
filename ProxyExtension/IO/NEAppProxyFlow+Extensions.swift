//
//  FlowInterface.swift
//  SplitTunnelProxyExtension
//
//  Created by John Mair on 12/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NetworkExtension

// Implement the shortcuts
extension NEAppProxyFlow: Flow {
    func closeReadAndWrite() {
        self.closeReadWithError(nil)
        self.closeWriteWithError(nil)
    }

    var sourceAppSigningIdentifier: String { self.metaData.sourceAppSigningIdentifier }
}

// Enforce Flow protocol conformance for NEAppProxyTCPFlow and NEAppProxyUDPFlow subclasses.
// This approach allows using Flow protocols universally instead of specific NEAppProxyFlow classes,
// facilitating easier stubbing/mocking in tests as Flow protocols are simpler to satisfy.
extension NEAppProxyTCPFlow: FlowTCP {}
extension NEAppProxyUDPFlow: FlowUDP {}
