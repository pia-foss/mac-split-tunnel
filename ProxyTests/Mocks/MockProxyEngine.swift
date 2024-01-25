//
//  MockProxyEngine.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 17/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NetworkExtension

class MockProxyEngine: ProxyEngineProtocol, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    // Required by ProxyEngineProtocol
    var vpnState: VpnState

    init() {
        self.vpnState = VpnState()
    }

    public func whitelistProxyInFirewall(groupName: String) -> Bool {
        record(args: [groupName])
        return true
    }

    public func setTunnelNetworkSettings(serverAddress: String, provider: NETransparentProxyProvider, completionHandler: @escaping (Error?) -> Void) {
        record(args: [serverAddress, provider, completionHandler])
    }

    public func handleNewFlow(_ flow: Flow) -> Bool {
        record(args: [flow])
        return true
    }
}

