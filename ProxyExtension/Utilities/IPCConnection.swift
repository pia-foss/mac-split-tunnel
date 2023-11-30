// The ProxyApp and the ProxyExtension processes comunicate using
// the IPCConnection class

// https://developer.apple.com/forums/thread/715338
// XPC wraps Mach messaging in an API that’s much easier to use
// An XPC connection represents a communication channel between two processes.
// An XPC listener listens for incoming connections.
// XPC has two APIs:
// - The low-level C API
// - The Foundation XPC API, commonly referred to by the main class name, NSXPCConnection (used here)

import Foundation
import os.log
import Network

/// App --> Provider IPC
@objc protocol ProviderCommunication {

    func register(_ completionHandler: @escaping (Bool) -> Void)
}

/// Provider --> App IPC
@objc protocol AppCommunication {

    func promptUser(aboutFlow flowInfo: [String: String], responseHandler: @escaping (Bool) -> Void)
}

enum FlowInfoKey: String {
    case localPort
    case remoteAddress
}

/// The IPCConnection class is used by both the app and the system extension to communicate with each other
class IPCConnection: NSObject {

    // MARK: Properties

    var listener: NSXPCListener?
    var currentConnection: NSXPCConnection?
    weak var delegate: AppCommunication?
    static let shared = IPCConnection()

    // MARK: Methods

    /**
        The NetworkExtension framework registers a Mach service with the name in the system extension's NEMachServiceName Info.plist key.
        The Mach service name must be prefixed with one of the app groups in the system extension's com.apple.security.application-groups entitlement.
        Any process in the same app group can use the Mach service to communicate with the system extension.
     */
    private func extensionMachServiceName(from bundle: Bundle) -> String {

        guard let networkExtensionKeys = bundle.object(forInfoDictionaryKey: "NetworkExtension") as? [String: Any],
            let machServiceName = networkExtensionKeys["NEMachServiceName"] as? String else {
                fatalError("Mach service name is missing from the Info.plist")
        }

        return machServiceName
    }

    func startListener() {

        let machServiceName = extensionMachServiceName(from: Bundle.main)
        os_log("Starting XPC listener for mach service \(machServiceName)")

        let newListener = NSXPCListener(machServiceName: machServiceName)
        newListener.delegate = self
        newListener.resume()
        listener = newListener
    }

    /// This method is called by the app to register with the provider running in the system extension.
    // called in registerWithProvider() in ViewController.swift
    // internal name for argument of type Bundle is bundle, used in the function.
    // withExtension is the external name of the same argument, used when the function is called.
    // sets the properties delegate and currentConnection
    func register(withExtension bundle: Bundle, delegate: AppCommunication, completionHandler: @escaping (Bool) -> Void) {

        os_log("Registering system in the app, with the provider running in the system Extension")
        self.delegate = delegate

        guard currentConnection == nil else {
            os_log("Already registered with the provider")
            completionHandler(true)
            return
        }

        let machServiceName = extensionMachServiceName(from: bundle)
        let newConnection = NSXPCConnection(machServiceName: machServiceName, options: [])

        // The exported object is the delegate.
        newConnection.exportedInterface = NSXPCInterface(with: AppCommunication.self)
        newConnection.exportedObject = delegate

        // The remote object is the provider's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: ProviderCommunication.self)

        currentConnection = newConnection
        newConnection.resume()

        guard let providerProxy = newConnection.remoteObjectProxyWithErrorHandler({ registerError in
            os_log("Failed to register with the provider: \(registerError.localizedDescription)")
            self.currentConnection?.invalidate()
            self.currentConnection = nil
            completionHandler(false)
        }) as? ProviderCommunication else {
            fatalError("Failed to create a remote object proxy for the provider")
        }

        providerProxy.register(completionHandler)
    }

    /**
        This method is called by the provider to cause the app (if it is registered) to display a prompt to the user asking
        for a decision about a connection.
    */
    func promptUser(aboutFlow flowInfo: [String: String], responseHandler:@escaping (Bool) -> Void) -> Bool {
        
        guard let connection = currentConnection else {
            os_log("Cannot prompt user because the app isn't registered")
            return false
        }

        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            os_log("Failed to prompt the user: \(promptError.localizedDescription)")
            self.currentConnection = nil
            responseHandler(true)
        }) as? AppCommunication else {
            fatalError("Failed to create a remote object proxy for the app")
        }

        // calls the function defined in ViewController.swift
        appProxy.promptUser(aboutFlow: flowInfo, responseHandler: responseHandler)

        return true
    }

}

// extensions for the class IPCConnection
extension IPCConnection: NSXPCListenerDelegate {

    // MARK: NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {

        // The exported object is this IPCConnection instance.
        newConnection.exportedInterface = NSXPCInterface(with: ProviderCommunication.self)
        newConnection.exportedObject = self

        // The remote object is the delegate of the app's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: AppCommunication.self)

        newConnection.invalidationHandler = {
            self.currentConnection = nil
        }

        newConnection.interruptionHandler = {
            self.currentConnection = nil
        }

        currentConnection = newConnection
        newConnection.resume()

        return true
    }
}

extension IPCConnection: ProviderCommunication {

    // MARK: ProviderCommunication

    func register(_ completionHandler: @escaping (Bool) -> Void) {

        os_log("App registered")
        completionHandler(true)
    }
}
