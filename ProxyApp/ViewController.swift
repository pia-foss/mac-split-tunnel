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
    
    var manager: NETransparentProxyManager?
    var localProxyConnectionAddress: String = ""
    var localProxyConnectionPort: String = ""
    var appsToManage: [String] = []
    
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
    
    // Get the Bundle of the system extension.
    lazy var extensionBundle: Bundle = {
        
        let extensionsDirectoryURL = URL(fileURLWithPath: "Contents/Library/SystemExtensions", relativeTo: Bundle.main.bundleURL)
        let extensionURLs: [URL]
        do {
            extensionURLs = try FileManager.default.contentsOfDirectory(at: extensionsDirectoryURL,
                                                includingPropertiesForKeys: nil,
                                                                   options: .skipsHiddenFiles)
        } catch let error {
            fatalError("Failed to get the contents of \(extensionsDirectoryURL.absoluteString): \(error.localizedDescription)")
        }
        
        guard let extensionURL = extensionURLs.first else {
            fatalError("Failed to find any system extensions")
        }
        
        guard let extensionBundle = Bundle(url: extensionURL) else {
            fatalError("Failed to create a bundle with URL \(extensionURL.absoluteString)")
        }
        
        return extensionBundle
    }()
    
    override func viewWillAppear() {
        super.viewWillAppear()
        status = .stopped
    }
    
    // MARK: UI BUTTONS
    @IBAction func activate(_ sender: Any) {
        activateExtension()
    }
    
    @IBAction func deactivate(_ sender: Any) {
        deactivateExtension()
        status = .stopped
    }
    
    @IBAction func loadManager(_ sender: Any) {
        loadManager() {
            self.createManager()
        }
    }
    
    @IBAction func startTunnel(_ sender: Any) {
        if status != .running {
            startTunnel(manager: self.manager!)
            status = .running
        }
    }
    
    // Stopping the tunnel is INCREDIBLY slow for some reason
    // It takes 5 full seconds from when the request is sent from
    // the app, until the actual MyTransparentProxy stops
    @IBAction func stopTunnel(_ sender: Any) {
        if status != .stopped {
            stopTunnel(manager: self.manager!)
            status = .stopped
        }
    }
}
