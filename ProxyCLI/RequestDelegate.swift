import Foundation
import SystemExtensions
import OSLog

// Callbacks invoked when a OSSystemExtensionRequest is completed.
// These functions must be implemented in order to respect the protocol
class ExtensionRequestDelegate: NSObject, OSSystemExtensionRequestDelegate {
    // Because we are using a non-ui client here, we add a completion handler 
    // we can use to the caller of when the delegate was called back.
    private let completionHandler: () -> Void

    init(completion: @escaping () -> Void) {
        completionHandler = completion
    }
        
    // this is executed when a request to a system (network) extension finished with a valid result
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        os_log("Request to system extension finished with result: %d", result.rawValue)

        if result != .completed {
            os_log("Unexpected result %d for system extension request", result.rawValue)
        }
        completionHandler()
    }

    // this is executed when a request to a system (network) extension failed with an error
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        print("System extension request failed: \(error) \(error.localizedDescription)")
        completionHandler()
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        os_log("Extension %@ requires user approval", request.identifier)
        completionHandler()
    }

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension extension: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        os_log("Replacing extension %@ version %@ with version %@", request.identifier, existing.bundleShortVersion, `extension`.bundleShortVersion)
        completionHandler()
        return .replace
    }
}
