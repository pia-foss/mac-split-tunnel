//
//  AppPolicy.swift
//  SplitTunnelProxyExtension
//
//  Created by John Mair on 19/12/2023.
//  Copyright © 2023 PIA. All rights reserved.
//

import Foundation

// Responsible for determining the policy to apply to a given app -
// We can either: proxy, block or ignore the app
// This object also depends on the routeVpn, connected, bypassApps,
// and vpnOnlyApps being up to date.
struct AppPolicy {
    // A term that covers both AppIDs and App Paths
    typealias Descriptor = String

    let vpnState: VpnState

    // The policy we should apply to an app
    enum Policy {
        case proxy, block, ignore
    }

    init(vpnState: VpnState) {
        self.vpnState = vpnState
    }

    public static func policyFor(_ descriptor: Descriptor, vpnState: VpnState) -> AppPolicy.Policy {
        AppPolicy(vpnState: vpnState).policyFor(descriptor)
    }

    // Determine the policy by Descriptor (either app ID or app path)
    // i.e com.apple.curl (for app id) or /usr/bin/curl (for app path)
    public func policyFor(_ descriptor: Descriptor) -> Policy {
        // If we're connected to the VPN then we just have to check
        // if the app is managed by us.
        if vpnState.connected {
            return isManagedApp(app: descriptor) ? .proxy : .ignore

        // If the VPN is not connected then we ignore all apps except vpnOnly apps
        // which we block.
        } else {
            return vpnState.vpnOnlyApps.contains(descriptor) ? .block : .ignore
        }
    }

    // A managed app is one that we proxy.
    // In the case of routeVpn == true, we check for the app in bypassApps:
    // this is because we need to proxy these apps to escape the default routing.
    // In the case routeVpn == false, we check for it in vpnOnlyApps
    // this is because we need to proxy these apps to bind them to the VPN interface.
    private func isManagedApp(app: String) -> Bool {
        return vpnState.routeVpn ? vpnState.bypassApps.contains(app) : vpnState.vpnOnlyApps.contains(app)
    }
}
