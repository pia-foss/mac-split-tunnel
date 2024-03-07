import Foundation
import NetworkExtension

// Protocol to abstract away NetworkInterface creation
protocol NetworkInterfaceFactory {
    func create(interfaceName: String) -> NetworkInterfaceProtocol
}

// Concrete implementation - the one we actually use in production.
final class DefaultNetworkInterfaceFactory: NetworkInterfaceFactory {
    public func create(interfaceName: String) -> NetworkInterfaceProtocol {
        NetworkInterface(interfaceName: interfaceName)
    }
}
