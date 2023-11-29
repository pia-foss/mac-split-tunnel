import Foundation
import Darwin
import NetworkExtension

extension Socket {
    func writeDataTCP(_ data: Data, completionHandler completion: @escaping (Error?) -> Void) {
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
    
    func readDataTCP(completionHandler completion: @escaping (Data?, Error?) -> Void) {
        var buffer = [UInt8](repeating: 0, count: 2048) // Adjust buffer size as needed
        let bytesRead = recv(fileDescriptor, &buffer, buffer.count, 0)
        if bytesRead > 0 {
            if bytesRead == 2048 {
                Logger.log.warning("Warning: \(appID) Read 2048 bytes in recv() in fd: \(fileDescriptor)")
            }
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
}
