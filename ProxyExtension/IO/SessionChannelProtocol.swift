import Foundation
import NIO

// Simplified interface for a NIO Channel - we use this instead of a real NIO Channel
// as it's a much simpler interface, contains everything we use - and
// is therefore much easier to use when stubbing/mocking in tests
protocol SessionChannel {
    var allocator: ByteBufferAllocator { get }
    var pipeline: ChannelPipeline { get }
    var isActive: Bool { get }
    func writeAndFlush<T>(_ any: T) -> EventLoopFuture<Void>
    func close() -> EventLoopFuture<Void>
}
