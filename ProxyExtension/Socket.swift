import Foundation
import Darwin
import os.log
import NetworkExtension
import Puppy

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

public enum SocketError: Error {
    case readNoData
    case readError
    case writeNoData
    case writeError
    case dataEndpointMismatchUDP
    case wrongAddressFamily
    case socketClosed
}

extension SocketError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .readNoData:
            return NSLocalizedString("Socket Read no data", comment: "")
        case .readError:
            return NSLocalizedString("Socket Read error", comment: "")
        case .writeNoData:
            return NSLocalizedString("Socket Wrote no data", comment: "")
        case .writeError:
            return NSLocalizedString("Socket Write error", comment: "")
        case .dataEndpointMismatchUDP:
            return NSLocalizedString("Socket UDP Data endpoint mismatch", comment: "")
        case .wrongAddressFamily:
            return NSLocalizedString("Socket Wrong address family", comment: "")
        case .socketClosed:
            return NSLocalizedString("Socket is closed", comment: "")
        }
    }
}

class Socket {
    var fileDescriptor: Int32
    var status: SocketStatus
    let transportProtocol: TransportProtocol
    let host: String?
    let port: UInt16?
    let appID: String
    
    init(transportProtocol: TransportProtocol, host: String, port: UInt16, appID: String) {
        fileDescriptor = -1
        status = .empty
        self.transportProtocol = transportProtocol
        self.host = host
        self.port = port
        self.appID = appID
    }
    
    init(transportProtocol: TransportProtocol, appID: String) {
        fileDescriptor = -1
        status = .empty
        self.transportProtocol = transportProtocol
        self.host = nil
        self.port = nil
        self.appID = appID
    }
    
    func create() -> Bool {
        switch transportProtocol {
        case .UDP:
            fileDescriptor = socket(AF_INET, SOCK_DGRAM, 0)
        case .TCP:
            fileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        }
        if fileDescriptor == -1 {
            let error = String(cString: strerror(errno))
            Logger.log.error("Error: \(appID) \"\(error)\" in socket() in fd: \(fileDescriptor)")
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
            let error = String(cString: strerror(errno))
            Logger.log.error("Error: \(appID) \"\(error)\" in connect() in fd: \(fileDescriptor)")
            close()
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
            Logger.log.warning("Warning: Written 0 bytes in \(appID) send(). The connection was gracefully closed by the peer in fd: \(fileDescriptor)")
            completion(SocketError.writeNoData)
        } else {
            let error = String(cString: strerror(errno))
            Logger.log.error("Error: \(appID) \"\(error)\" in send() in fd: \(fileDescriptor)")
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
            Logger.log.warning("Warning: \(appID) Received 0 bytes in recv(). The connection was gracefully closed by the peer in fd: \(fileDescriptor)")
            completion(nil, SocketError.readNoData)
        } else {
            let error = String(cString: strerror(errno))
            Logger.log.error("Error: \(appID) \"\(error)\" in recv() in fd: \(fileDescriptor)")
            completion(nil, SocketError.readError)
        }
    }
    
    func writeDataUDP(_ dataArray: [Data], _ endpoints: [NWEndpoint], completionHandler completion: @escaping (Error?) -> Void) {
        var writeError: SocketError? = nil
        if dataArray.count != endpoints.count {
            Logger.log.error("Error: \(appID) Number of data packets do not match number of endpoints in writeDataUDP() in fd: \(fileDescriptor)")
            completion(SocketError.dataEndpointMismatchUDP)
        } else {
            for (data, endpoint) in zip(dataArray, endpoints) {
                let endpointParts = getAddressAndPort(endpoint: endpoint as! NWHostEndpoint)
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
                    Logger.log.warning("Warning: \(appID) Written 0 bytes in sendto(). The connection was gracefully closed by the peer in fd: \(fileDescriptor)")
                    writeError = SocketError.writeNoData
                } else if bytesWritten < 0 {
                    let error = String(cString: strerror(errno))
                    Logger.log.error("Error: \(appID) \"\(error)\" in sendto() in fd: \(fileDescriptor)")
                    writeError = SocketError.writeError
                }
            }
            completion(writeError)
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
            completion(data, endpoint, nil as Error?)
        } else if bytesRead == 0 {
            // When recvfrom() returns 0 or -1, it is no longer possible 
            // to read or write to the socket
            Logger.log.warning("Warning: \(appID) Received 0 bytes in recvfrom(). The connection was gracefully closed by the peer in fd: \(fileDescriptor)")
            completion(nil as Data?, nil as NWEndpoint?, SocketError.readNoData)
        } else {
            let error = String(cString: strerror(errno))
            Logger.log.error("Error: \(appID) \"\(error)\" in recvfrom() in fd: \(fileDescriptor)")
            completion(nil as Data?, nil as NWEndpoint?, SocketError.readError)
        }
    }
    
    func close() {
        if fileDescriptor != -1 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
        }
        status = .closed
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
            let error = String(cString: strerror(errno))
            Logger.log.error("Error: \(appID) \"\(error)\" in bind() in fd: \(fileDescriptor)")
            return false
        }
        return true
    }
}
