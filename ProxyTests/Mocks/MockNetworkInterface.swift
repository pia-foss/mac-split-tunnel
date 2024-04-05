import Foundation

@testable import SplitTunnelProxyExtensionFramework
final class MockNetworkInterface: NetworkInterfaceProtocol, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    let ip: String

    init(ip: String = "192.168.100.1") {
        self.ip = ip
    }

    // Required by NetworkInterface
    var interfaceName = "en0"

    func ip4() -> String? {
        record()
        return ip
    }
}
