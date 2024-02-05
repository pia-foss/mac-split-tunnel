import Foundation

// Given a flow, find the policy for that flow - ignore, block, proxy
// This class just wraps AppPolicy, which takes an app "descriptor", either
// an appID or a full path to an executable. It first tries to find a policy based
// on appID, and failing that (if it gets back an .ignore) it tries the full path which
// it extracts from the flow audit token.
final class FlowPolicy {
    let vpnState: VpnState

    init(vpnState: VpnState) {
        self.vpnState = vpnState
    }

    public static func policyFor(flow: Flow, vpnState: VpnState) -> AppPolicy.Policy {
        FlowPolicy(vpnState: vpnState).policyFor(flow: flow)
    }

    public static func modeFor(flow: Flow, vpnState: VpnState) -> AppPolicy.Mode {
        FlowPolicy(vpnState: vpnState).modeFor(flow: flow)
    }

    // Given a flow, return the app policy to apply (.proxy, .block. ignore)
    public func policyFor(flow: Flow) -> AppPolicy.Policy {
        guard let descriptor = descriptorFor(flow: flow) else {
            return .ignore
        }

        let policy = AppPolicy.policyFor(descriptor, vpnState: vpnState)
        let mode = AppPolicy.modeFor(descriptor, vpnState: vpnState)

        // Block Ipv6 vpnOnly flows regardless of policy
        // Do not block Ipv6 bypass flows (let them get proxied)
        if mode == .vpnOnly && flow.isIpv6() {
            return .block
        } else {
            return policy
        }
    }

    public func modeFor(flow: Flow) -> AppPolicy.Mode {
        guard let descriptor = descriptorFor(flow: flow) else {
            return .unspecified
        }
        return AppPolicy.modeFor(descriptor, vpnState: vpnState)
    }

    public func descriptorFor(flow: Flow) -> String? {
        // First try to find an identifier for the app using the appId
        let appID = flow.sourceAppSigningIdentifier
        if !appID.isEmpty {
            return appID
        } else {
            // Fall back to appPath if appID is not available
            return pathFromAuditToken(token: flow.sourceAppAuditToken)
        }
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
        guard let path = getProcessPath(pid: pid) else {
            log(.warning, "Found a process with pid \(pid) but could not convert to a path")
            return nil
        }

        return path
    }
}
