
import Foundation

@testable import SplitTunnelProxy
import Quick
import Nimble

final class NetworkInterfaceTest: QuickSpec {
    override class func spec() {
        describe("NetworkInterfaceTest") {
            context("with invalid interface name") {
                it("fails to retrieve an ip") {
                    let interface = NetworkInterface(interfaceName: "foobar")
                    expect(interface.ip4()).to(beNil())
                }
            }

            context("with a valid interface name") {
                it("retrieves the ip") {
                    // Assumption is that 127.0.0.1 is the only ipv4 ip
                    // bound to lo0 - should be true in most cases
                    let interface = NetworkInterface(interfaceName: "lo0")
                    let ip = interface.ip4()!
                    expect(ip).to(equal("127.0.0.1"))
                }
            }
        }
    }
}

