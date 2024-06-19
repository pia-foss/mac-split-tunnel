/**
This is the main of the ProxyApp GUI client, a graphical client for the extension process.
This is a viable way of managing the system extension.
Right now, it's only used during development work.
 
This GUI is not shipped with PIA desktop client,
which uses the cli client ProxyCLI.
Both the gui and the cli client share the same functionalities.
 */

import SwiftUI
import Foundation

@main
struct ProxyAppGUI: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
