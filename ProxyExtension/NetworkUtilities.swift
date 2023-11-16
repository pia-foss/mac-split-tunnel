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
    let address = (endpoint as! NWHostEndpoint).hostname
    let port = UInt16((endpoint as! NWHostEndpoint).port)
    return (address, port)
}

func createNWEndpoint(fromSockAddr addr: sockaddr_in) -> NWHostEndpoint {
    // Convert IPv4 address to string
    var ipAddr = addr.sin_addr
    var address = withUnsafePointer(to: &ipAddr) { ipPtr -> String in
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, ipPtr, &buffer, socklen_t(INET_ADDRSTRLEN))
        return String(cString: buffer)
    }

    // Convert port number to string
    let port = String(UInt16(addr.sin_port).byteSwapped) // ntohs(addr.sin_port) in C

    // Create NWHostEndpoint with the address and port
    let endpoint = NWHostEndpoint(hostname: address, port: port)

    return endpoint
}

func closeFlow(_ flow: NEAppProxyFlow) {
    // close the flow when you dont want to read and write to it anymore
    flow.closeReadWithError(nil)
    flow.closeWriteWithError(nil)
}
