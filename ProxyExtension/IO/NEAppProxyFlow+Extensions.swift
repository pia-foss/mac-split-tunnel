import Foundation
import NetworkExtension

// Implement the shortcuts
extension NEAppProxyFlow: Flow {
    func closeReadAndWrite() {
        self.closeReadWithError(nil)
        self.closeWriteWithError(nil)
    }

    func openFlow(completionHandler: @escaping (Error?) -> Void) {
        open(withLocalEndpoint: nil, completionHandler: completionHandler)
    }

    var sourceAppSigningIdentifier: String { self.metaData.sourceAppSigningIdentifier }
    var sourceAppAuditToken: Data? { self.metaData.sourceAppAuditToken }
}

// Enforce Flow protocol conformance for NEAppProxyTCPFlow and NEAppProxyUDPFlow subclasses.
// This approach allows using Flow protocols universally instead of specific NEAppProxyFlow classes,
// facilitating easier stubbing/mocking in tests as Flow protocols are simpler to satisfy.
extension NEAppProxyTCPFlow: FlowTCP {}
extension NEAppProxyUDPFlow: FlowUDP {}
