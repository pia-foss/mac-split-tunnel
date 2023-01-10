/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file contains initialization code for the system extension.
*/

// Change this to run the application
//DEPLOYMENT_LOCATION = YES
//DSTROOT = /
//INSTALL_PATH = $(LOCAL_APPS_DIR)/MyDevelopmentApps
//SKIP_INSTALL = NO

// The system authorizes apps that a developer notarizes and distributes directly to users.

import Foundation
import NetworkExtension

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
