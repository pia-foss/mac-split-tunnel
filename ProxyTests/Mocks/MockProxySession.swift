import Foundation

// Mocks a ProxySession - for use in tests
@testable import SplitTunnelProxyExtensionFramework
final class MockProxySession: ProxySession, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    // Required by ProxySession
    var id: IDGenerator.ID = 0

    func start() {
        record()
    }
    
    func terminate() {
        record()
    }
}
