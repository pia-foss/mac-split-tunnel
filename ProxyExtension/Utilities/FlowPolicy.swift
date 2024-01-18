//
//  FlowPolicy.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 18/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

// Given a flow, find the policy for that flow - ignore, block, proxy
final class FlowPolicy {
    let vpnState: VpnState

    init(vpnState: VpnState) {
        self.vpnState = vpnState
    }

    public static func policyFor(flow: Flow, vpnState: VpnState) -> AppPolicy.Policy {
        FlowPolicy(vpnState: vpnState).policyFor(flow: flow)
    }

    // Given a flow, return the app policy to apply (.proxy, .block. ignore)
    public func policyFor(flow: Flow) -> AppPolicy.Policy {
        // First try to find a policy for the app using the appId
        let appID = flow.sourceAppSigningIdentifier
        let appIdPolicy = AppPolicy.policyFor(appID, vpnState: vpnState)

        // If we fail to find a policy from the appId
        // then try using the path (extracted from the audit token)
        // Otherwise, if we find a policy from the appID, return that policy
        guard appIdPolicy == .ignore else {
            return appIdPolicy
        }

        // We failed to find a policy based on appId - let's try the app path
        // In order to find the app path we first have to extract it from the flow's audit token
        let auditToken = flow.sourceAppAuditToken

        guard let path = pathFromAuditToken(token: auditToken) else {
            return .ignore
        }

        // Return the policy for the app (by its path)
        return AppPolicy.policyFor(path, vpnState: vpnState)
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

            // The full C signature is: audit_token_to_au32(audit_token_t atoken, uid_t *auidp, uid_t *euidp, gid_t *egidp, uid_t *ruidp, gid_t *rgidp, pid_t *pidp, au_asid_t *asidp, au_tid_t *tidp)
            // We pass in nil if we're not interested in that value - here we only want the PID, so that's all we request.
            audit_token_to_au32(auditTokenValue, nil, nil, nil, nil, nil, &pid, nil, nil)
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
