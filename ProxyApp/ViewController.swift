/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file contains the implementation of the primary NSViewController class.
*/

import Cocoa
import NetworkExtension
import SystemExtensions
import os.log

/**
    The ViewController class implements the UI functions of the app, including:
      - Activating the system extension and enabling the content filter configuration when the user clicks on the Start button
      - Disabling the content filter configuration when the user clicks on the Stop button
      - Prompting the user to allow or deny connections at the behest of the system extension
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
    @IBOutlet var logTextView: NSTextView!
    
    // ? means that manager may contain a NETransparentProxyManager or nil
    var manager: NETransparentProxyManager?
    var loadedManager: Bool = false
    var serverAddress: String = ""
    var serverPort: String = ""
    var rulesHosts: [String] = []
    var observer: Any?
    
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
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
    
    override func viewWillDisappear() {
        
        super.viewWillDisappear()
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
        loadManager()
        loadedManager = true
    }
    
    @IBAction func makeManager(_ sender: Any) {
        if loadedManager == true {
            createManager()
        } else {
            os_log("load the manager first!")
        }
    }
    
    @IBAction func startTunnel(_ sender: Any) {
        startTunnel(manager: self.manager!)
        status = .running
    }
    
    @IBAction func stopTunnel(_ sender: Any) {
        stopTunnel(manager: self.manager!)
        status = .stopped
    }
}
