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
            subcommands: [Activate.self, Deactivate.self, Status.self, Version.self])
    }
}

extension ProxyCLI.SysExt {
    struct Activate: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "activate",
            abstract: "Activate the system extension.")

        mutating func run() async throws{
            do {
                let (description, _) = try Status.getSystemExtensionStatus(false)
                if description == "bundled" {
                    // Already done, no need to activate
                    print("Already activated")
                    return
                }
            }
            catch {
                print("Error checking system extension status")
            }
            requestActivation()
        }
    }

    struct Deactivate: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "deactivate",
            abstract: "Deactivate the system extension.")

        mutating func run() {
            do {
                let (description, _) = try Status.getSystemExtensionStatus(false)
                if description == "none" {
                    print("Already deactivated")
                    return
                }
                if description == "other" {
                    // We want to deactivate a different version.
                    // That can be problematic, so activate the bundled version first.
                    // This should not require user confirmation
                    requestActivation()
                }
                assert(description == "bundled")
            }
            catch {
                print("Error checking system extension status")
            }
            requestDeactivation()
        }
    }
    
    struct Status: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Get system extension status.")
        
        @Flag(help: "Be verbose")
        var verbose: Bool = false
        
        mutating func run() throws {
            let (description, status) = try Status.getSystemExtensionStatus(verbose)
            print(description, status)
        }
        
        static func getSystemExtensionStatus(_ verbose: Bool) throws -> (String, String) {
            // A better solution would use `OSSystemExtensionRequest.propertiesRequest`, but it is not
            // supported on macOS 11, our minimum target.
            // Instead we simply call `systemextensionsctl list` and parse the output.

            /*
             * Run systemextensionsctl
             */
            let process = Process()
            let pipe = Pipe()

            process.standardOutput = pipe
            process.arguments = ["list"]
            process.executableURL = URL(fileURLWithPath: "/usr/bin/systemextensionsctl")
            
            do {
                try process.run()
            } catch {
                print("Error: \(error)")
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output: String = String(data: data, encoding: .utf8) ?? ""

            /*
             * Parse the output
             * It's in a columnar format, so we first find the rows we care about
             * by looking for the bundle id, then we clean each row, split it into
             * the columns and check for version matches.
             */

            // Get the bundled version to compare with the output
            let (bundledVersion, bundledBuild) = try getBundledVersion()

            let lines = output.split(separator: "\n")
            let extensionLines = lines.filter { $0.contains(splitTunnelBundleId) }
            for line in extensionLines {
                // The output uses asterisks to show whether it's enabled and inactive
                // in a way that is tricky to parse.
                // Here we simply replace all possible cases for more explicit values
                let modifiedLine = line
                    .replacingOccurrences(of: "*\t*\t", with: "enabled\tactive\t")
                    .replacingOccurrences(of: "*\t\t", with: "enabled\tinactive\t")
                    .replacingOccurrences(of: "\t*\t", with: "disabled\tactive\t")
                    .replacingOccurrences(of: "\t\t", with: "disabled\tinactive\t")
                
                if verbose {
                    // Useful for dev, shows what the status command sees
                    print(modifiedLine)
                }
                var extensionInfo = modifiedLine.split(separator: "\t")
                let enabled = extensionInfo[0] == "enabled"
                let active = extensionInfo[1] == "active"
                
                if !enabled && !active {
                    // Old, uninstalled version, ignore
                    continue
                }
                
                // Remove parenthesis from the version string
                extensionInfo[3].removeAll(where: {["(",")"].contains($0)})
                // Extract version and build number
                let versions = extensionInfo[3].split(separator: " ")[1].split(separator: "/")
                
                var systemVersion = "other"
                var status = "unknown"
                if versions[0] == bundledVersion && versions[1] == bundledBuild {
                    // The system is dealing with the same version as the one bundled in this app
                    systemVersion = "bundled"
                }
                if !enabled && active {
                    // Waiting for user permission in system settings
                    status = "waiting_for_user"
                }
                else if enabled && active {
                    status = "installed"
                }
                
                return (systemVersion, status)
            }

            // Nothing matched or matches are waiting to be uninstalled
            return("none", "uninstalled")
        }
    }

    struct Version: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "version",
            abstract: "Get the version and build number of the bundled network extension.")

        mutating func run() throws {
            let (bundleVersion, bundleBuild) = try getBundledVersion()
            print(bundleVersion, bundleBuild)
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

func getBundledVersion() throws -> (String, String){
    let bundle = getExtensionBundleID()
    let bundledShortVersion = bundle.infoDictionary!["CFBundleShortVersionString"]!
    let bundledVersion = bundle.infoDictionary!["CFBundleVersion"]!
    return ((bundledShortVersion as? String)!, (bundledVersion as? String)!)
}
