import Foundation
import Darwin
import NetworkExtension

extension Socket {
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
                endpointAddress.sin_port = UInt16(endpointParts.1!.bigEndian)
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
            if bytesRead == 2048 {
                Logger.log.warning("Warning: \(appID) Read 2048 bytes in recvfrom() in fd: \(fileDescriptor)")
            }
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
}
