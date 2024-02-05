import Foundation

// Responsible for determining the policy to apply to a given app -
// We can either: proxy, block or ignore the app
struct AppPolicy {
    // A term that covers both AppIDs and App Paths
    typealias Descriptor = String

    private let vpnState: VpnState

    private let bypassApps: [String]
    private let vpnOnlyApps: [String]

    // The policy we should apply to an app
    enum Policy {
        case proxy, block, ignore
    }

    // Is the app - bypass, vpnOnly or unspecified
    // unspecified means there is no rule for the app, and it
    // should follow the system default
    enum Mode {
        case bypass, vpnOnly, unspecified
    }

    init(vpnState: VpnState) {
        self.vpnState = vpnState
        // Normalize app descriptors to lowercase
        self.bypassApps = vpnState.bypassApps.map { $0.lowercased() }
        self.vpnOnlyApps = vpnState.vpnOnlyApps.map { $0.lowercased() }
    }

    public static func policyFor(_ descriptor: Descriptor, vpnState: VpnState) -> AppPolicy.Policy {
        AppPolicy(vpnState: vpnState).policyFor(descriptor)
    }

    public static func modeFor(_ descriptor: Descriptor, vpnState: VpnState) -> Mode {
        AppPolicy(vpnState: vpnState).modeFor(descriptor)
    }

    public func modeFor(_ descriptor: Descriptor) -> Mode {
        // Normalize the descriptor
        let normalizedDescriptor = descriptor.lowercased()

        // Assumption here is that an app cannot be in both lists at once
        if isMatchedApp(normalizedDescriptor, appList: bypassApps) {
            return .bypass
        } else if isMatchedApp(normalizedDescriptor, appList: vpnOnlyApps) {
            return .vpnOnly
        }

        return .unspecified
    }

    // Determine the policy by Descriptor (either app ID or app path)
    // i.e com.apple.curl (for app id) or /usr/bin/curl (for app path)
    public func policyFor(_ descriptor: Descriptor) -> Policy {
        // Normalize the descriptor
        let normalizedDescriptor = descriptor.lowercased()
        // If we're connected to the VPN then we just have to check
        // if the app is proxied.
        if vpnState.isConnected {
            return isProxiedApp(normalizedDescriptor) ? .proxy : .ignore

        // If the VPN is not connected then we ignore all apps except vpnOnly apps
        // which we block.
        } else {
            return isMatchedApp(normalizedDescriptor, appList: vpnOnlyApps) ? .block : .ignore
        }
    }

    // An app that we proxy.
    // In the case of routeVpn == true, we check for the app in bypassApps:
    // this is because we need to proxy these apps to escape the default routing.
    // In the case routeVpn == false, we check for it in vpnOnlyApps
    // this is because we need to proxy these apps to bind them to the VPN interface.
    private func isProxiedApp(_ descriptor: String) -> Bool {
        let managedApps = vpnState.routeVpn ? bypassApps : vpnOnlyApps
        return isMatchedApp(descriptor, appList: managedApps)
    }

    // Is the app found in the given list?
    // We treat app bundle ids differently - if a given bundle id
    // shares a root with one in our list, then we match it too.
    // i.e com.google.chrome.helper will 'match' an id in our list with just com.google.chrome
    private func isMatchedApp(_ descriptor: String, appList: [String]) -> Bool {
        if isAppBundleId(descriptor) {
            return appList.contains { descriptor.hasPrefix($0) }
        } else {
            return appList.contains(descriptor)
        }
    }

    // Determine if a string represents an app bundle or a binary path.
    // We consider an app anything that is made entirely of numbers,
    // letters, and the period sign `.`
    // That discards any binary path, as they necessarily contain slashes `/`.
    private func isAppBundleId(_ descriptor: String) -> Bool {
        let bundleCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        return descriptor.unicodeScalars.allSatisfy { bundleCharacters.contains($0) }
    }
}
