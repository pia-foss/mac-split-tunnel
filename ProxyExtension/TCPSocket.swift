import Foundation
import Darwin
import os.log
import Network

enum SocketStatus {
    case empty
    case created
    case connected
    case closed
}

enum SocketError: Error {
    case readError
    case writeError
}

@available(macOS 11.0, *)
class TCPSocket {
    var fileDescriptor: Int32
    var status: SocketStatus
    let host: String
    let port: UInt16
    let appName: String
    
    init(host: String, port: UInt16, appName: String) {
        fileDescriptor = -1
        status = .empty
        self.host = host
        self.port = port
        self.appName = appName
    }
    
    func create() -> Bool {
        fileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        if fileDescriptor == -1 {
            os_log("Error when creating the socket!")
            perror("socket")
            return false
        }
        status = .created
        return true
    }
    
    func setOptions () -> Bool {
        var reuse: Int32 = 1
        if setsockopt(fileDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size)) == -1 {
            os_log("Error when setting the socket options!")
            perror("setsockopt")
            return false
        }
        return true
    }
    
    func connectToHost() -> Bool {
        var serverAddress = sockaddr_in()
        serverAddress.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        serverAddress.sin_family = sa_family_t(AF_INET)
        serverAddress.sin_port = port.bigEndian // Specify the port in network byte order
        serverAddress.sin_addr.s_addr = inet_addr(host)

        let connectResult = withUnsafePointer(to: &serverAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fileDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if connectResult == -1 {
            os_log("Error when setting the socket options!")
            perror("connect")
            closeConnection() // is this needed if the attemp to connect() failed?
            return false
        }
        status = .connected
        return true
    }
    
    func writeData(_ data: Data, completionHandler completion: @escaping (Error?) -> Void) {
        let bytesWritten = data.withUnsafeBytes {
            send(fileDescriptor, $0.baseAddress, data.count, 0)
        }
        if bytesWritten == -1 {
            os_log("Error when writing data to the socket!")
            perror("send")
            completion(SocketError.writeError)
        } else {
            completion(nil)
        }
    }
    
    func readData(completionHandler completion: @escaping (Data?, Error?) -> Void) {
        var buffer = [UInt8](repeating: 0, count: 2048) // Adjust buffer size as needed
        let bytesRead = recv(fileDescriptor, &buffer, buffer.count, 0)
        if bytesRead == -1 {
            os_log("Error when reading data from the socket!")
            perror("recv")
            completion(nil, SocketError.readError)
        } else if bytesRead > 0 {
            completion(Data(bytes: buffer, count: bytesRead), nil)
        } else { // is reading 0 bytes from a socket an error? (verify this!)
            completion(nil, nil)
        }
    }
    
    func closeConnection() {
        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
            status = .closed
        }
    }

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
    
    func bindToNetworkInterface(interfaceName: String) -> Bool {
        let interfaceAddress = getNetworkInterfaceIP(interfaceName: interfaceName)
        
        var interface_addr = sockaddr_in()
        interface_addr.sin_family = sa_family_t(AF_INET)
        interface_addr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        interface_addr.sin_addr.s_addr = inet_addr(interfaceAddress)

        let bindResult = withUnsafePointer(to: &interface_addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fileDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if bindResult == -1 {
            os_log("Error when binding to physical interface!")
            perror("bind")
            return false
        }
        return true
    }
}
