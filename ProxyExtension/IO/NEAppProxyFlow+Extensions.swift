import Foundation
import NetworkExtension

// Simulate a "Connection refused" error
let connectionRefused = NSError(domain: NSPOSIXErrorDomain, code: Int(ECONNREFUSED), userInfo: nil)

// Implement the shortcuts
extension NEAppProxyFlow: Flow {
    // Kill a flow
    func closeReadAndWrite() {
        self.closeReadWithError(connectionRefused)
        self.closeWriteWithError(connectionRefused)
    }

    // Open a flow
    func openFlow(completionHandler: @escaping (Error?) -> Void) {
        open(withLocalEndpoint: nil, completionHandler: completionHandler)
    }

    // Flow metadata
    var sourceAppSigningIdentifier: String { self.metaData.sourceAppSigningIdentifier }
    var sourceAppAuditToken: Data? { self.metaData.sourceAppAuditToken }
}

// Enforce Flow protocol conformance for NEAppProxyTCPFlow and NEAppProxyUDPFlow subclasses.
// This approach allows using Flow protocols universally instead of specific NEAppProxyFlow classes,
// facilitating easier stubbing/mocking in tests as Flow protocols are simpler to satisfy.
extension NEAppProxyTCPFlow: FlowTCP {}
extension NEAppProxyUDPFlow: FlowUDP {}
