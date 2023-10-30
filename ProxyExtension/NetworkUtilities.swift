import Foundation
import NetworkExtension

func getNetworkInterfaceIP(interfaceName: String) -> String? {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { return nil }
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name: String = String(cString: (interface.ifa_name))
                if  name == interfaceName {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
    }
    return address
}

func getAddressAndPort(endpoint: NWEndpoint) -> (String?, UInt16?) {
    let parts = endpoint.description.split(separator: ":", maxSplits: 1)
    guard parts.count == 2 else {
        return (nil, nil)
    }
    let address = String(parts[0])
    let port = UInt16(parts[1])
    return (address, port)
}
