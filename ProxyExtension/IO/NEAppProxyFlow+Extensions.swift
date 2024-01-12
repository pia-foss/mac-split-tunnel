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

    var sourceAppSigningIdentifier: String {
        get { self.metaData.sourceAppSigningIdentifier }
    }
}

// Force conformance of subclasses to the protocol too
// This is also useful for testing - so we can pass in our own
// mock/stubs which conform to the protocol
extension NEAppProxyTCPFlow: FlowTCP {}
extension NEAppProxyUDPFlow: FlowUDP {}
