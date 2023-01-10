/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file contains the implementation of the NEFilterDataProvider sub-class.
*/

// modifying the code here creates a new network extension
// this message is printed in the stdout of the application
// "Replacing extension com.privateinternetaccess.splittunnel.poc.extension version 1.0 with version 1.0"
// using the command "systemextensionsctl list" it shows two network extensions:
// 2 extension(s)
// --- com.apple.system_extension.network_extension
// enabled    active    teamID    bundleID (version)    name    [state]
//        5357M5NW9W    com.privateinternetaccess.splittunnel.poc.extension (1.0/1)    SimpleFirewallExtension    [terminated waiting to uninstall on reboot]
// *    *    5357M5NW9W    com.privateinternetaccess.splittunnel.poc.extension (1.0/1)    SimpleFirewallExtension    [activated enabled]
// It appears there is no need to manually use this command:
// "systemextensionsctl uninstall 5357M5NW9W com.privateinternetaccess.splittunnel.poc"
// which requires SIP to be disabled, which is something we can't ask a user to do.

// the debugger does not reach this code, probably cause it is executed by the network extension process.
// these logs are not printed in the stdout of the application, when debugging the app.

import NetworkExtension
import os.log

/**
    The FilterDataProvider class handles connections that match the installed rules by prompting
    the user to allow or deny the connections.
    The NEFilterDataProvider class declares the programmatic interface for an object that evaluates network data flows based on a set of locally-available rules and makes decisions about whether to block or allow the flows.
 */
class FilterDataProvider: NEFilterDataProvider {

    // MARK: Properties

    // The TCP port which the filter is interested in.
	static let localPort = "8888"

    // MARK: START OF FILTER RULES

    // the function that contains the rules
    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
               
        os_log("Starting Filter in Extension")
        // ORIGINAL CODE
            // Filter incoming TCP connections on port 8888
            let filterRules = ["0.0.0.0", "::"].map { address -> NEFilterRule in
                let localNetwork = NWHostEndpoint(hostname: address, port: FilterDataProvider.localPort)
                let remoteNetwork = NWHostEndpoint(hostname: "0.0.0.0", port: FilterDataProvider.localPort)
//                let inboundNetworkRule = NENetworkRule(remoteNetwork: nil,
                let inboundNetworkRule = NENetworkRule(remoteNetwork: remoteNetwork,
                                                       remotePrefix: 0,
//                                                       localNetwork: localNetwork,
                                                       localNetwork: nil,
                                                       localPrefix: 0,
                                                       protocol: .any,
//                                                       direction: .inbound)
                                                       direction: .outbound)
                return NEFilterRule(networkRule: inboundNetworkRule, action: .filterData)
            }
            // Allow all flows that do not match the filter rules.
            let filterSettings = NEFilterSettings(rules: filterRules, defaultAction: .allow)
        
        // NEW CODE
//            let anyHostAndPortRule = NENetworkRule(
//                        remoteNetwork: NWHostEndpoint(hostname: "0.0.0.0", port: FilterDataProvider.localPort),
//                        remotePrefix: 0,
//                        localNetwork: nil,
//                        localPrefix: 0,
//                        protocol: .any,
//                        direction: .outbound  // can be outbound, inbound or any
//                    )
//
//            let filterRule = NEFilterRule(networkRule: anyHostAndPortRule, action: .filterData)
//            let filterSettings = NEFilterSettings(rules: [filterRule], defaultAction: .allow)

        apply(filterSettings) { error in
            if let applyError = error {
                os_log("Failed to apply filter settings: %@", applyError.localizedDescription)
            }
            completionHandler(error)
        }
        os_log("Started Filter in Extension")
    }
    
    // MARK: END OF FILTER RULES
    
    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {

        completionHandler()
    }
    
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {

        os_log("Handling new flow a new flow: %{public}@", flow.description)
        
        // The conditional cast operator as? tries to perform a conversion,
        // but returns nil if it can't. Thus its result is optional.
        guard let socketFlow = flow as? NEFilterSocketFlow,
            let remoteEndpoint = socketFlow.remoteEndpoint as? NWHostEndpoint,
            let localEndpoint = socketFlow.localEndpoint as? NWHostEndpoint else {
                return .allow()
        }

        os_log("Got a new flow with local endpoint %@, remote endpoint %@", localEndpoint, remoteEndpoint)

        let flowInfo = [
            FlowInfoKey.localPort.rawValue: localEndpoint.port,
            FlowInfoKey.remoteAddress.rawValue: remoteEndpoint.hostname
        ]

        // Ask the app to prompt the user
        let prompted = IPCConnection.shared.promptUser(aboutFlow: flowInfo) { allow in
            let userVerdict: NEFilterNewFlowVerdict = allow ? .allow() : .drop()
            self.resumeFlow(flow, with: userVerdict)
        }

        guard prompted else {
            return .allow()
        }

        return .pause()
    }
}

