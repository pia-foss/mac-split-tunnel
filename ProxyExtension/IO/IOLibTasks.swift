import Foundation
import NetworkExtension

class IOLibTasks : IOLib {
    func handleReadAndWrite(_ tProtocol: TransportProtocol, _ flow: NEAppProxyFlow, _ socket: Socket) {
        // These two functions are async using escaping completion handler
        //
        // Whenever any error is detected in any of these functions, the flow is
        // closed as suggested by mother Apple (the application will likely deal
        // with the dropped connection).
        //
        // semaphore.wait() triggers this warning:
        // Instance method 'wait' is unavailable from asynchronous contexts;
        // Await a Task handle instead; this is an error in Swift 6
        Task.detached(priority: .high) {
            let semaphore = DispatchSemaphore(value: 0)
            while (socket.status != .closed) {
                switch tProtocol {
                    case .TCP:
                        TCPIO.handleRead(flow as! NEAppProxyTCPFlow, socket, semaphore)
                    case .UDP:
                        UDPIO.handleRead(flow as! NEAppProxyUDPFlow, socket, semaphore)
                }
                semaphore.wait()
            }
            Logger.log.info("\(socket.appID) Exit read \(tProtocol) task in fd: \(socket.fileDescriptor)")
        }
        Task.detached(priority: .high) {
            let semaphore = DispatchSemaphore(value: 0)
            while (socket.status != .closed) {
                switch tProtocol {
                    case .TCP:
                        TCPIO.handleWrite(flow as! NEAppProxyTCPFlow, socket, semaphore)
                    case .UDP:
                        UDPIO.handleWrite(flow as! NEAppProxyUDPFlow, socket, semaphore)
                }
                semaphore.wait()
            }
            Logger.log.info("\(socket.appID) Exit write \(tProtocol) task in fd: \(socket.fileDescriptor)")
        }
    }
}
