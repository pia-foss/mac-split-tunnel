import Foundation
import NetworkExtension

extension NetworkExtension.NWHostEndpoint {
    var networkEndpoint: Network.NWEndpoint? {
        let host = Network.NWEndpoint.Host(self.hostname)
        guard let port = Network.NWEndpoint.Port(self.port) else {
              return nil
        }

        return Network.NWEndpoint.hostPort(host: host, port: port)
    }

    var string: String {
        return "\(hostname)|\(port)"
    }
}
