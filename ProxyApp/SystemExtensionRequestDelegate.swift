import Foundation
import NetworkExtension
import SystemExtensions
import os.log

// Callbacks invoked when a OSSystemExtensionRequest is completed.
// These functions must be implemented in order to respect the protocol
extension ViewController: OSSystemExtensionRequestDelegate {

    // MARK: OSSystemExtensionActivationRequestDelegate

    // this is executed when a request to a system (network) extension finished with a valid result
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        
        os_log("Request to system extension finished with result: %d", result.rawValue)

        guard result == .completed else {
            os_log("Unexpected result %d for system extension request", result.rawValue)
            status = .stopped
            return
        }
    }

    // this is executed when a request to a system (network) extension failed with an error
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {

        os_log("System extension request failed: %@", error.localizedDescription)
        status = .stopped
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {

        os_log("Extension %@ requires user approval", request.identifier)
    }

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension extension: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {

        os_log("Replacing extension %@ version %@ with version %@", request.identifier, existing.bundleShortVersion, `extension`.bundleShortVersion)
        return .replace
    }
}
