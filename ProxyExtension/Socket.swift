import Foundation
import Darwin
import os.log
import Network
import NetworkExtension

enum TransportProtocol {
    case UDP
    case TCP
}

enum SocketStatus {
    case empty
    case created
    case connected
    case closed
}

enum SocketError: Error {
    case readNoData
    case readError
    case writeNoData
    case writeError
    case dataEndpointMismatchUDP
    case wrongAddressFamily
}

@available(macOS 11.0, *)
class Socket {
    var fileDescriptor: Int32
    var status: SocketStatus
    let transportProtocol: TransportProtocol
    let host: String?
    let port: UInt16?
    let appName: String
    
    init(transportProtocol: TransportProtocol, host: String, port: UInt16, appName: String) {
        fileDescriptor = -1
        status = .empty
        self.transportProtocol = transportProtocol
        self.host = host
        self.port = port
        self.appName = appName
    }
    
    init(transportProtocol: TransportProtocol, appName: String) {
        fileDescriptor = -1
        status = .empty
        self.transportProtocol = transportProtocol
        self.host = nil
        self.port = nil
        self.appName = appName
    }
    
    func create() -> Bool {
        switch transportProtocol {
        case .UDP:
            fileDescriptor = socket(AF_INET, SOCK_DGRAM, 0)
        case .TCP:
            fileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        }
        if fileDescriptor == -1 {
            os_log("Error when creating the socket!")
            perror("socket")
            return false
        }
        status = .created
        return true
    }
    
    func connectToHost() -> Bool {
        var serverAddress = sockaddr_in()
        serverAddress.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        serverAddress.sin_family = sa_family_t(AF_INET)
        serverAddress.sin_port = port!.bigEndian // Specify the port in network byte order
        serverAddress.sin_addr.s_addr = inet_addr(host!)

        let connectResult = withUnsafePointer(to: &serverAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fileDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if connectResult == -1 {
            os_log("Error when calling connect()")
            perror("connect")
            closeConnection()
            return false
        }
        status = .connected
        return true
    }
    
    func writeData(_ data: Data, completionHandler completion: @escaping (Error?) -> Void) {
        let bytesWritten = data.withUnsafeBytes {
            send(fileDescriptor, $0.baseAddress, data.count, 0)
        }
        if bytesWritten > 0 {
            completion(nil)
        } else if bytesWritten == 0 {
            // When send() returns 0 or -1, it is no longer possible to
            // read or write to the socket
            os_log("send(): The connection was gracefully closed by the peer")
            completion(SocketError.writeNoData)
        } else {
            os_log("Error when calling send()")
            perror("send")
            completion(SocketError.writeError)
        }
    }
    
    func readData(completionHandler completion: @escaping (Data?, Error?) -> Void) {
        var buffer = [UInt8](repeating: 0, count: 2048) // Adjust buffer size as needed
        let bytesRead = recv(fileDescriptor, &buffer, buffer.count, 0)
        if bytesRead > 0 {
            completion(Data(bytes: buffer, count: bytesRead), nil)
        } else if bytesRead == 0 {
            // When recv() returns 0 or -1, it is no longer possible to
            // read or write to the socket
            os_log("recv(): The connection was gracefully closed by the peer")
            completion(nil, SocketError.readNoData)
        } else {
            os_log("Error when calling recv()")
            perror("recv")
            completion(nil, SocketError.readError)
        }
    }
    
    func writeDataUDP(_ dataArray: [Data], _ endpoints: [NetworkExtension.NWEndpoint], completionHandler completion: @escaping (Error?) -> Void) {
        var error: SocketError? = nil
        if dataArray.count != endpoints.count {
            os_log("number of data packets do not match number of endpoints")
            completion(SocketError.dataEndpointMismatchUDP)
        } else {
            for (data, endpoint) in zip(dataArray, endpoints) {
                let endpointParts = getAddressAndPort(endpoint: endpoint)
                var endpointAddress = sockaddr_in()
                endpointAddress.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
                endpointAddress.sin_family = sa_family_t(AF_INET)
                endpointAddress.sin_port = endpointParts.1!.bigEndian
                endpointAddress.sin_addr.s_addr = inet_addr(endpointParts.0!)
                let serverSocketAddress = withUnsafePointer(to: &endpointAddress) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        $0
                    }
                }
                
                let bytesWritten = data.withUnsafeBytes { dataBuffer in
                    sendto(fileDescriptor, dataBuffer.baseAddress, data.count, 0, serverSocketAddress, socklen_t(MemoryLayout<sockaddr>.size))
                }
                if bytesWritten == 0 {
                    // When sendto() returns 0 or -1, it is no longer
                    // possible to read or write to the socket
                    os_log("sendto(): The connection was gracefully closed by the peer")
                    error = SocketError.writeNoData
                } else if bytesWritten < 0 {
                    os_log("Error when calling sendto()")
                    perror("sendto")
                    error = SocketError.writeError
                }
            }
            completion(error)
        }
    }
    
    func readDataUDP(completionHandler completion: @escaping (Data?, NetworkExtension.NWEndpoint?, Error?) -> Void) {
        var buffer = [UInt8](repeating: 0, count: 2048) // Adjust buffer size as needed
        var sourceAddress = sockaddr_in()
        let sourceAddressPointer = withUnsafeMutablePointer(to: &sourceAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                $0
            }
        }
        var sourceAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let bytesRead = recvfrom(fileDescriptor, &buffer, buffer.count, 0, sourceAddressPointer, &sourceAddressLength)
        if bytesRead > 0 {
            let endpoint = createNWEndpoint(fromSockAddr: sourceAddress)
            let data = Data(bytes: buffer, count: bytesRead)
            completion(data, endpoint, nil)
        } else if bytesRead == 0 {
            // When recvfrom() returns 0 or -1, it is no longer possible 
            // to read or write to the socket
            os_log("recvfrom(): The connection was gracefully closed by the peer")
            completion(nil, nil, SocketError.readNoData)
        } else {
            os_log("Error when calling recvfrom()")
            perror("recvfrom")
            completion(nil, nil, SocketError.readError)
        }
    }
    
    func closeConnection() {
        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
            status = .closed
        }
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
            os_log("Error when when calling bind()")
            perror("bind")
            return false
        }
        return true
    }
}
