import Foundation
import NetworkExtension

// Mocks a FlowTCP for use in tests
@testable import SplitTunnelProxyExtensionFramework
final class MockFlowTCP: FlowTCP, Equatable, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    let data: Data?
    let flowError: Error?

    init(data: Data? = nil, flowError: Error? = nil) {
        self.data = data
        self.flowError = flowError
    }

    // Useful for certain assertions
    static func ==(lhs: MockFlowTCP, rhs: MockFlowTCP) -> Bool {
        return lhs === rhs
    }

    // Required by Flow
    func closeReadAndWrite() { record() }
    func openFlow(completionHandler: @escaping (Error?) -> Void) {
        record(args: [completionHandler])
        completionHandler(nil)
    }
    public var sourceAppSigningIdentifier: String = "quinn"
    public var remoteHostname: String? = nil
    public var sourceAppAuditToken: Data? = nil

    // Required by FlowTCP
    public var remoteEndpoint: NWEndpoint = NWHostEndpoint(hostname: "8.8.8.8", port: "1337")

    // Reads from our flow
    // Unlike the real readData on NEAppProxyTCPFlow this does not dispatch the
    // completion handler to another thread so we must be careful about how we
    // use it to avoid infinite recursion.
    func readData(completionHandler: @escaping (Data?, Error?) -> Void) {
        record(args: [completionHandler])
        completionHandler(data, flowError)
    }

    // Writes to our flow
    func write(_ data: Data, withCompletionHandler completionHandler: @escaping (Error?) -> Void) {
        record(args: [data, completionHandler])
        completionHandler(flowError)
    }
}
