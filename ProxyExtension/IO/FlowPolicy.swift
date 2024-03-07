import Foundation

// Given a flow, find the policy for that flow - ignore, block, proxy
// This class wraps AppPolicy, which takes an app "descriptor", either
// an appID or a full path to an executable. It first tries to find a policy based
// on appID, and failing that (if it gets back an .ignore) it tries the full path which
// it extracts from the flow audit token.
// Beyond just wrapping AppPolicy it takes into account flow-related info
// such as whether the flow is ipv6 or ipv4, etc.
final class FlowPolicy {
    let vpnState: VpnState
    let utils: ProcessUtilitiesProtocol

    init(vpnState: VpnState) {
        self.vpnState = vpnState
        self.utils = ProcessUtilities()
    }

    public static func policyFor(flow: Flow, vpnState: VpnState) -> AppPolicy.Policy {
        FlowPolicy(vpnState: vpnState).policyFor(flow: flow)
    }

    public static func modeFor(flow: Flow, vpnState: VpnState) -> AppPolicy.Mode {
        FlowPolicy(vpnState: vpnState).modeFor(flow: flow)
    }

    // Given a flow, return the app policy to apply (.proxy, .block. ignore)
    public func policyFor(flow: Flow) -> AppPolicy.Policy {
        // Closure to encapsulate the decision logic based on policy, mode, and IPv6 check
        let determinePolicy: (String) -> AppPolicy.Policy = { descriptor in
            let policy = AppPolicy.policyFor(descriptor, vpnState: self.vpnState)
            let mode = AppPolicy.modeFor(descriptor, vpnState: self.vpnState)

            // Special-case ALWAYS block vpnOnly ipv6 Flows!
            if mode == .vpnOnly, flow.isIpv6() {
                return .block
            } else {
                return policy
            }
        }

        // Attempt to determine the policy using the flow's source app signing identifier
        let policyUsingAppId = determinePolicy(flow.sourceAppSigningIdentifier)
        if policyUsingAppId != .ignore {
            return policyUsingAppId
        }

        // If the policy is .ignore, attempt to determine the policy using the path from the flow's source app audit token
        if let path = pathFromAuditToken(token: flow.sourceAppAuditToken) {
            return determinePolicy(path)
        }

        // If unable to determine a non-ignore policy, return .ignore
        return .ignore
    }

    // Returns the mode - i.e vpnOnly, bypass or unspecified for a given flow
    public func modeFor(flow: Flow) -> AppPolicy.Mode {
        let modeForAppId = AppPolicy.modeFor(flow.sourceAppSigningIdentifier, vpnState: self.vpnState)

        if modeForAppId != .unspecified {
            return modeForAppId
        }

        // If we got .unspecified for the appId - try again using the app path
        if let path = pathFromAuditToken(token: flow.sourceAppAuditToken) {
            return AppPolicy.modeFor(path, vpnState: vpnState)
        }

        return .unspecified
    }

    // Given an audit token of an app flow - extract out the executable path for
    // the app generating the flow.
    private func pathFromAuditToken(token: Data?) -> String? {
        guard let auditToken = token else {
            log(.warning, "Audit token is nil")
            return nil
        }

        // The pid of the process behind the flow
        var pid: pid_t = 0

        // An audit token is opaque Data - but we can use it to extract the pid (and other things)
        // by converting it to an audit_token_t and then using libbsm APIs to extract what we want.
        auditToken.withUnsafeBytes { bytes in
            let auditTokenValue = bytes.bindMemory(to: audit_token_t.self).baseAddress!.pointee

            pid = audit_token_to_pid(auditTokenValue)
        }

        guard pid != 0 else {
            log(.warning, "Could not get a pid from the audit token")
            return nil
        }

        // Get the executable path from the pid
        guard let path = utils.getProcessPath(pid: pid) else {
            log(.warning, "Found a process with pid \(pid) but could not convert to a path")
            return nil
        }

        return path
    }
}
