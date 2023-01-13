//
//  NWHostEndPoint.swift
//  SplitTunnelProxy
//
//  Created by Michele Emiliani on 11/01/23.
//  Copyright © 2023 PIA. All rights reserved.
//

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
