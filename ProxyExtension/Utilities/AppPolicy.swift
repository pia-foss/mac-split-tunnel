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
    // The policy we should apply to an app
    enum Policy {
        case proxy, block, ignore
    }

    // List of apps which bypass the VPN
    var bypassApps: [String] = []
    // List of apps which bind to the VPN
    var vpnOnlyApps: [String] = []
    // Whether the VPN has the default route (true means it does)
    var routeVpn: Bool = false
    // Whether the VPN is connected
    var connected: Bool = false

    // Determine the policy by appId (i.e com.apple.curl)
    func policyFor(appId: String) -> Policy {
        // If we're connected to the VPN then we just have to check
        // if the app is managed by us.
        if connected {
            return isManagedApp(app: appId) ? .proxy : .ignore

        // If the VPN is not connected then we ignore all apps except vpnOnly apps
        // which we block.
        } else {
            return vpnOnlyApps.contains(appId) ? .block : .ignore
        }
    }

    // Determine the policy by app path (i.e /usr/bin/curl)
    func policyFor(appPath: String) -> Policy {
        return policyFor(appId: appPath)
    }

    // A managed app is one that we proxy.
    // In the case of routeVpn == true, we check for the app in bypassApps:
    // this is because we need to proxy these apps to escape the default routing.
    // In the case routeVpn == false, we check for it in vpnOnlyApps
    // this is because we need to proxy these apps to bind them to the VPN interface.
    private func isManagedApp(app: String) -> Bool {
        return routeVpn ? bypassApps.contains(app) : vpnOnlyApps.contains(app)
    }
}
