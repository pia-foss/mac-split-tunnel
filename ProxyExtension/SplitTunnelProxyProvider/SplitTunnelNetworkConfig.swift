import Foundation
import NetworkExtension

struct SplitTunnelNetworkConfig {
    let serverAddress: String
    let provider: NETransparentProxyProvider

    func apply(_ completionHandler: @escaping (Error?) -> Void) {
        let settings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: serverAddress)
        settings.includedNetworkRules = includedNetworkRules()
        settings.excludedNetworkRules = excludedNetworkRules()

        // Because this method executes the block asynchronously, we can't just
        // return true/false (Bool) to indicate applying the settings was successful
        // the only way to indicate it is by executing the completionHandler callback
        // either with nil (success) or error (failure) - that is also why
        // the setTunnelNetworkSettings is a Void method
        // The completionHandler callback when invoked with an error will prevent
        // the proxy starting.
        provider.setTunnelNetworkSettings(settings) { error in
            if (error != nil) {
                log(.error, "\(error!.localizedDescription) when setting proxy settings")
                completionHandler(error)
            }

            // This is needed in order to make the proxy connect.
            // If omitted the proxy will hang in the "Connecting..." state
            completionHandler(nil)
        }
    }

    // Build a rule to match traffic from a subnet and a prefix - default to all protocols (TCP/UDP) and outbound only
    // A nil subnet implies remoteNetwork should be set to nil (which means it'll match all remote networks)
    private func subnetRule(subnet: String?, prefix: Int) -> NENetworkRule {
        return NENetworkRule(
            // port "0" means any port
            remoteNetwork: subnet != nil ? NWHostEndpoint(hostname: subnet!, port: "0") : nil,
            remotePrefix: prefix,
            localNetwork: nil,
            localPrefix: 0,
            protocol: .any,
            direction: .outbound
        )
    }

    // The rules (aka subnets) that will be managed by our proxy
    // - everything - but note that the includedNetworkRules are subsequently
    // constrained by the excludedNetworkRules
    private func includedNetworkRules() -> [NENetworkRule] {
        // We want to be "notified" of all flows (TCP and UDP), so we can decide which to manage.
        // nil subnet and 0 prefix indicate we want to match everything
        let allNetworks = subnetRule(subnet: nil, prefix: 0)
        return [allNetworks]
    }

    // The subnets that will not be managed by our proxy (LAN networks for now)
    private func excludedNetworkRules() -> [NENetworkRule] {
        // Exclude IPv4 LAN networks from the proxy
        // We don't need to exclude localhost as this is excluded by default
        let rfc1918NetworkRules = [
            // LAN subnets
            subnetRule(subnet: "192.168.0.0", prefix: 16),
            subnetRule(subnet: "10.0.0.0", prefix: 8),
            subnetRule(subnet: "172.16.0.0", prefix: 12),
            // local-host
            subnetRule(subnet: "127.0.0.0", prefix: 8)
        ]

        // Exclude IPv6 LAN networks from the proxy
        let ipv6LocalNetworkRules = [
            // unique local
            subnetRule(subnet: "fc00::", prefix: 7),
            // link-local
            subnetRule(subnet: "fe80::", prefix: 10),
            // multi-cast
            subnetRule(subnet: "ff00::", prefix: 8),
            // local-host (unlike ipv4, this is a single address not a subnet)
            subnetRule(subnet: "::1", prefix: 128)
        ]

        return rfc1918NetworkRules + ipv6LocalNetworkRules
    }
}
