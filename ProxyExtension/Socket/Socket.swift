import Foundation
import Darwin
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
