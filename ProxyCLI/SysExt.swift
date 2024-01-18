import Foundation
import SystemExtensions
import NetworkExtension
import OSLog
import ArgumentParser

let splitTunnelBundleId = "com.privateinternetaccess.vpn.splittunnel"

extension ProxyCLI {
    struct SysExt: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "sysext",
            abstract: "Manage the system extension.",
            subcommands: [Activate.self, Deactivate.self])
    }
}

extension ProxyCLI.SysExt {
    struct Activate: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "activate",
            abstract: "Activate the system extension.")

        mutating func run() async throws{
            requestActivation()
        }
    }

    struct Deactivate: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "deactivate",
            abstract: "Deactivate the system extension.")

        mutating func run() {
            // TODO: If not activated yet, don't do anything
            requestActivation()
            requestDeactivation()
        }
    }
}

func request(_ request: OSSystemExtensionRequest) {
    var done = false
    let delegate = ExtensionRequestDelegate {
        done = true
    }

    request.delegate = delegate
    OSSystemExtensionManager.shared.submitRequest(request)
    while !done {
        Thread.sleep(forTimeInterval: 0.1)
    }
}

func requestActivation() {
    let activationRequest = OSSystemExtensionRequest.activationRequest(
        forExtensionWithIdentifier: splitTunnelBundleId,
        queue: .main
    )
    request(activationRequest)
}

func requestDeactivation()  {
    let deactivationRequest = OSSystemExtensionRequest.deactivationRequest(
        forExtensionWithIdentifier: splitTunnelBundleId,
        queue: .main
    )
    request(deactivationRequest)
}

