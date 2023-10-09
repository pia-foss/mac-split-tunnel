import Foundation
import Darwin

class TCPSocket {
    var fileDescriptor: Int32
    let interface = "en0"
    let host: String
    let port: UInt16
    
    init(host: String, port: UInt16) {
        fileDescriptor = -1
        self.host = host
        self.port = port
    }
    
    // Create a socket
    func create() {
        fileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        if fileDescriptor == -1 {
            perror("socket")
            exit(-1)
        }
    }
    
    // Set socket options to allow reuse of the address and port
    func setOptions () {
        var reuse: Int32 = 1
        if setsockopt(fileDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size)) == -1 {
            perror("setsockopt")
            exit(-1)
        }
    }
    
    // Connect to a remote server
    func connectToHost() {
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
            perror("connect")
            exit(-1)
        }
    }
    
    // Write data to the socket
    func writeData(data: Data) {
        let bytesWritten = data.withUnsafeBytes {
            send(fileDescriptor, $0.baseAddress, data.count, 0)
        }
        if bytesWritten == -1 {
            perror("send")
            exit(-1)
        }
    }
    
    // Read data from the socket
    func readData() -> Data? {
        var buffer = [UInt8](repeating: 0, count: 1024) // Adjust buffer size as needed
        let bytesRead = recv(fileDescriptor, &buffer, buffer.count, 0)
        if bytesRead <= 0 {
            // Error or connection closed
            return nil
        }
        return Data(bytes: buffer, count: bytesRead)
    }
    
    func closeConnection() {
        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }
    
    //  on macos you dont need to bind to en0, just setting source ip of socket is enough
    func bindToPhysicalInterface() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var pointer = ifaddr
            while pointer != nil {
                let interfaceName = String(cString: (pointer?.pointee.ifa_name)!)
                if interfaceName == interface {
                    if let sa = pointer?.pointee.ifa_addr {
                        var serverAddress = sockaddr_in()
                        serverAddress.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
                        serverAddress.sin_family = sa.pointee.sa_family
                        serverAddress.sin_port = 0 // Use 0 to bind to any available port
                        serverAddress.sin_addr.s_addr = inet_addr("0.0.0.0") // Bind to any available IP address on the interface

                        // Bind the socket to the specified interface and port
                        let bindResult = withUnsafePointer(to: &serverAddress) {
                            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                                bind(fileDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                            }
                        }

                        if bindResult == -1 {
                            perror("bind")
                            exit(-1)
                        }
                        break
                    }
                }
                pointer = pointer?.pointee.ifa_next
            }
            freeifaddrs(ifaddr)
        }
    }
}
