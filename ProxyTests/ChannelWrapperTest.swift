@testable import SplitTunnelProxy
import Quick
import Nimble
import NetworkExtension
import NIO

class OutboundHandler: ChannelOutboundHandler {
    typealias OutboundIn = ByteBuffer
    var lastWrittenData: String?

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let byteBuffer = self.unwrapOutboundIn(data)

        // Store the written data for testing
        lastWrittenData =  byteBuffer.getString(at: 0, length: byteBuffer.readableBytes)
        promise?.succeed()
    }
}

class ChannelWrapperTest: QuickSpec {
    override class func spec() {
        describe("ChannelWrapperTest") {
            context("when invoking channel methods on the wrapper") {
                it("delegates to the underlying channel") {
                    let handler = OutboundHandler()
                    let channel = EmbeddedChannel()
                    let wrapper = ChannelWrapper(channel)

                    // delegation
                    try! wrapper.pipeline.addHandler(handler).wait()
                    // delegation
                    var buffer = wrapper.allocator.buffer(capacity: 10)
                    buffer.writeString("Hello world")
                    let expectedString = buffer.getString(at: 0, length: buffer.readableBytes)
                    
                    // delegation
                    _ = try? wrapper.writeAndFlush(buffer).wait()

                    // delegation
                    _ = try? wrapper.close().wait()

                    // Verify the delegated methods worked
                    expect(handler.lastWrittenData!).to(equal(expectedString))
                }
            }
        }
    }
}
