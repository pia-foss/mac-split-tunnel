// This is the entry point for the network extension process

import Foundation
import NetworkExtension
import os.log

// TODO: Ensure that logs from ProxyExtension are accessible and
//       printed to stdout during debug

// https://betterprogramming.pub/what-is-autorelease-pool-in-swift-c652784f329e
autoreleasepool {
    // Start the Network Extension machinery in a system extension (.system bundle).
    // This class method will cause the calling system extension to start handling requests from
    // nesessionmanager to instantiate appropriate NEProvider sub-class instances.
    // The system extension must declare a mapping of Network Extension extension points to NEProvider subclass instances in its Info.plist.
    NEProvider.startSystemExtensionMode()
    IPCConnection.shared.startListener()
}

dispatchMain()
