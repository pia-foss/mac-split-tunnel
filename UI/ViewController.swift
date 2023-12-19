import Cocoa
import NetworkExtension
import SystemExtensions
import os.log

/**
This is the viewController of the GUI controlling the
ProxyApp, frontend for the system extension background process.
Ideally this will be abandoned and these functions will be called by the PIA client.
We will probably need some bindings for that.
 */
class ViewController: NSViewController {
    
    var proxyApp = ProxyAppDefault()
    
    enum Status {
        case stopped
        case indeterminate
        case running
    }
    
    // MARK: Properties
    @IBOutlet var statusIndicator: NSImageView!
    @IBOutlet var statusSpinner: NSProgressIndicator!
    @IBOutlet var startButton: NSButton!
    @IBOutlet var stopButton: NSButton!
    
    var status: Status = .stopped {
        didSet {
            // Update the UI to reflect the new status
            switch status {
            case .stopped:
                statusIndicator.image = #imageLiteral(resourceName: "dot_red")
                statusSpinner.stopAnimation(self)
                statusSpinner.isHidden = true
            case .indeterminate:
                statusIndicator.image = #imageLiteral(resourceName: "dot_yellow")
                statusSpinner.startAnimation(self)
                statusSpinner.isHidden = false
            case .running:
                statusIndicator.image = #imageLiteral(resourceName: "dot_green")
                statusSpinner.stopAnimation(self)
                statusSpinner.isHidden = true
            }
            
            if !statusSpinner.isHidden {
                statusSpinner.startAnimation(self)
            } else {
                statusSpinner.stopAnimation(self)
            }
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        status = .stopped
    }
    
    // MARK: UI BUTTONS
    @IBAction func activate(_ sender: Any) {
        proxyApp.setBypassApps(apps: ["com.privateinternetaccess.splittunnel.testapp", "net.limechat.LimeChat-AppStore", "org.mozilla.firefox", "/opt/homebrew/bin/wget"])
        proxyApp.setVpnOnlyApps(apps: ["/usr/bin/curl"])
        proxyApp.setNetworkInterface(interface: "en0")
        guard proxyApp.activateExtension() else {
            fatalError("Failed to activate the extension")
        }
    }
    
    @IBAction func deactivate(_ sender: Any) {
        guard proxyApp.deactivateExtension() else {
            fatalError("Failed to deactivate the extension")
        }
        status = .stopped
    }
    
    @IBAction func loadManager(_ sender: Any) {
        guard proxyApp.loadOrInstallProxyManager() else {
            fatalError("Failed to load or install the proxy manager")
        }
    }
    
    @IBAction func startTunnel(_ sender: Any) {
        if status != .running {
            guard proxyApp.startProxy() else {
                fatalError("Failed to start the proxy")
            }
            status = .running
        }
    }
    
    @IBAction func stopTunnel(_ sender: Any) {
        if status != .stopped {
            guard proxyApp.stopProxy() else {
                fatalError("Failed to stop the proxy")
            }
            status = .stopped
        }
    }
}
