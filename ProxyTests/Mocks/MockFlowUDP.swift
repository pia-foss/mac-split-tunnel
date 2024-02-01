//
import Foundation
import NetworkExtension

// Mocks a FlowUDP for use in tests
@testable import SplitTunnelProxyExtensionFramework
final class MockFlowUDP: FlowUDP, Equatable, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    let data: [Data]?
    let endpoints: [NWEndpoint]?
    let flowError: Error?

    init(data: [Data]? = nil, endpoints: [NWEndpoint]? = nil, flowError: Error? = nil) {
        self.data = data
        self.endpoints = endpoints
        self.flowError = flowError
    }

    // Useful for certain assertions
    static func ==(lhs: MockFlowUDP, rhs: MockFlowUDP) -> Bool {
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

    // Required by FlowUDP
    func readDatagrams(completionHandler: @escaping ([Data]?, [NWEndpoint]?, Error?) -> Void) {
        record(args: [completionHandler])
        completionHandler(data, endpoints, flowError)
    }

    func writeDatagrams(_ datagrams: [Data], sentBy remoteEndpoints: [NWEndpoint], completionHandler: @escaping (Error?) -> Void) {
        record(args: [datagrams, remoteEndpoints, completionHandler])
        completionHandler(flowError)
    }
}
