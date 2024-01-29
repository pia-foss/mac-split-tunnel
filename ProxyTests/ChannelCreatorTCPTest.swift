@testable import SplitTunnelProxy
import Quick
import Nimble
import NetworkExtension
import NIO

final class ChannelCreatorTCPTest: QuickSpec {
    override class func spec() {

        // Unlike with UDP we cannot test the happy path for TCP channel creation
        // as it makes a connect() - and it would require a significant amount
        // of re-organization to make it testable. We still get ~85% coverage of
        // the class just by testing the two unhappy paths, so it's fine for now.
        describe("ChannelCreatorTCPTest") {
            context("with an invalid bind Ip (but well-formed)") {
                it("fails to create the channel") {
                    let mockFlow = MockFlowTCP()
                    let config = SessionConfig(
                        // Use an invalid IP. Even though it's well-formed it is
                        // invalid because it won't match any
                        // Ip assigned to any of the local interfaces
                        interface: MockNetworkInterface(ip: "1.1.1.1"),
                        eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1))

                    let channelCreator = ChannelCreatorTCP(id: 0, flow:  mockFlow, config: config)

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

            context("with an invalid bind Ip (not well-formed)") {
                // This also fails in the same way as an invalid but well-formed ip
                // but takes a slightly different code path
                it("fails to create the channel") {
                    let mockFlow = MockFlowTCP()
                    let config = SessionConfig(
                        // Garbage ip - not well-formed.
                        interface: MockNetworkInterface(ip: "asdfasd"),
                        eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1))

                    let channelCreator = ChannelCreatorTCP(id: 0, flow:  mockFlow, config: config)

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

