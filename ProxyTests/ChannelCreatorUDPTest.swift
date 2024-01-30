import Quick
import Nimble
import NetworkExtension
import NIO

@testable import SplitTunnelProxyExtensionFramework
final class ChannelCreatorUDPTest: QuickSpec {
    override class func spec() {

        describe("ChannelCreatorUDPTest") {
            context("with valid bind Ip") {
                it("successfully create the channel") {
                    let mockFlow = MockFlowUDP()
                    let config = SessionConfig(
                        // Use a localhost IP - a bind is guaranteed to succeed
                        interface: MockNetworkInterface(ip: "127.0.0.1"),
                        eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1))

                    let channelCreator = ChannelCreatorUDP(id: 0, flow:  mockFlow, config: config)

                    let future = channelCreator.create { count in }
                    
                    var isInvoked = false
                    future.whenSuccess { channel in
                        isInvoked = true
                    }

                    // Can throw, but we ignore it so we can resolve the future
                    _ = try? future.wait()

                    expect(isInvoked).to(beTrue())
                }
            }

            context("with invalid bind Ip (but well-formed)") {
                it("fails to create the channel") {
                    let mockFlow = MockFlowUDP()
                    let config = SessionConfig(
                        // Use an invalid IP. Even though it's well-formed it is
                        // invalid because it won't match any
                        // Ip assigned to any of the local interfaces
                        interface: MockNetworkInterface(ip: "8.8.8.8"),
                        eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1))

                    let channelCreator = ChannelCreatorUDP(id: 0, flow:  mockFlow, config: config)

                    let future = channelCreator.create { count in }

                    var isInvoked = false
                    future.whenFailure { error in
                        isInvoked = true
                    }

                    // Can throw, but we ignore it so we can resolve the future
                    _ = try? future.wait()

                    expect(isInvoked).to(beTrue())
                }
            }

            context("with invalid bind Ip (garbage address, not an ip address)") {
                // This also fails in the same way as an invalid but well-formed ip
                // but takes a slightly different code path
                it("fails to create the channel") {
                    let mockFlow = MockFlowUDP()
                    let config = SessionConfig(
                        // Use an invalid IP - garbage, not even an ip
                        interface: MockNetworkInterface(ip: "asdfasd"),
                        eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1))

                    let channelCreator = ChannelCreatorUDP(id: 0, flow:  mockFlow, config: config)

                    let future = channelCreator.create { count in }

                    var isInvoked = false
                    future.whenFailure { error in
                        isInvoked = true
                    }

                    // Can throw, but we ignore it so we can resolve the future
                    _ = try? future.wait()

                    expect(isInvoked).to(beTrue())
                }
            }
        }
    }
}
