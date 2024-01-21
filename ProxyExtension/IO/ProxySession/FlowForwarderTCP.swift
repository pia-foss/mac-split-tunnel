import Foundation
import NIO
import NetworkExtension

// Responsible for reading data from the flow and writing to the
// corresponding channel
final class FlowForwarderTCP {
    typealias ByteCountFunc = (UInt64) -> Void
    let flow: FlowTCP
    let channel: SessionChannel
    let id: IDGenerator.ID

    init(id: IDGenerator.ID, flow: FlowTCP, channel: SessionChannel) {
        self.id = id
        self.flow = flow
        self.channel = channel
    }

    public func scheduleFlowRead(_ onBytesTransmitted: @escaping ByteCountFunc) {
        flow.readData { outboundData, flowError in
            if flowError == nil, let data = outboundData, !data.isEmpty  {
                self.forwardToChannel(data: data, onBytesTransmitted: onBytesTransmitted)
            } else {
                self.handleReadError(error: flowError)
            }
        }
    }

    private func handleReadError(error: Error?) {
        log(.error, "id: \(self.id)" +
            " \((error?.localizedDescription) ?? "Empty buffer") occurred during" +
            " TCP flow.readData()")

        if let error = error as NSError? {
            // Error code 10 is "A read operation is already pending"
            // We don't want to terminate the session if that is the error we got
            if error.domain == "NEAppProxyFlowErrorDomain" && error.code == 10 {
                return
            }
        }
        self.terminate()
    }

    private func forwardToChannel(data: Data, onBytesTransmitted: @escaping ByteCountFunc) {
        let buffer = channel.allocator.buffer(bytes: data)
        let writeFuture = self.channel.writeAndFlush(buffer)
        writeFuture.whenSuccess {
            // Update number of bytes transmitted
            onBytesTransmitted(UInt64(data.count))
            self.scheduleFlowRead(onBytesTransmitted)
        }

        writeFuture.whenFailure { error in
            log(.error, "id: \(self.id) \(error) while sending a TCP datagram through the socket")
            self.terminate()
        }
    }

    private func terminate() {
        ProxySessionTCP.terminateProxySession(id: id, channel: channel, flow: flow)
    }
}
