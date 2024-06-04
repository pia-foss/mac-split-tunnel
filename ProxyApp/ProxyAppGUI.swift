/**
This is the main of the ProxyApp GUI client, the extension graphical client.
This is a viable way of managing the system extension,
but it's only used during development work.
 
This GUI is not shipped with PIA desktop client.
The integrated project communicate with the extension
using only the cli client ProxyCLI.
Both share the same functionalities.
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
