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
      - Logging connections in a NSTextView
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
    
    // MARK: Update the UI
    func logFlow(_ flowInfo: [String: String], at date: Date, userAllowed: Bool) {

        guard let localPort = flowInfo[FlowInfoKey.localPort.rawValue],
            let remoteAddress = flowInfo[FlowInfoKey.remoteAddress.rawValue],
            let font = NSFont.userFixedPitchFont(ofSize: 12.0) else {
                return
        }

        let dateString = dateFormatter.string(from: date)
        let message = "\(dateString) \(userAllowed ? "ALLOW" : "DENY") \(localPort) <-- \(remoteAddress)\n"

        os_log("%@", message)

        let logAttributes: [NSAttributedString.Key: Any] = [ .font: font, .foregroundColor: NSColor.textColor ]
        let attributedString = NSAttributedString(string: message, attributes: logAttributes)
        logTextView.textStorage?.append(attributedString)
    }
    
    // MARK: CONTENT FILTER LOGIC
/*
    func registerWithProvider() {
        IPCConnection.shared.register(withExtension: extensionBundle, delegate: self) { success in
            DispatchQueue.main.async {
                self.status = (success ? .running : .stopped)
            }
        }
    }

    func loadFilterConfiguration(completionHandler: @escaping (Bool) -> Void) {

        NEFilterManager.shared().loadFromPreferences { loadError in
            DispatchQueue.main.async {
                var success = true
                if let error = loadError {
                    os_log("Failed to load the filter configuration: %@", error.localizedDescription)
                    success = false
                }
                completionHandler(success)
            }
        }
    }
    
    func enableFilterConfiguration() {

        let filterManager = NEFilterManager.shared()

        guard !filterManager.isEnabled else {
            registerWithProvider()
            return
        }

        loadFilterConfiguration { success in

            guard success else {
                self.status = .stopped
                return
            }

            if filterManager.providerConfiguration == nil {
                let providerConfiguration = NEFilterProviderConfiguration()
                providerConfiguration.filterSockets = true
                providerConfiguration.filterPackets = false
                filterManager.providerConfiguration = providerConfiguration
                if let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String {
                    filterManager.localizedDescription = appName
                }
            }

            filterManager.isEnabled = true

            filterManager.saveToPreferences { saveError in
                DispatchQueue.main.async {
                    if let error = saveError {
                        os_log("Failed to save the filter configuration: %@", error.localizedDescription)
                        self.status = .stopped
                        return
                    }

                    self.registerWithProvider()
                }
            }
        }
    }
*/
}
/*
// function that gets called when a new connection
extension ViewController: AppCommunication {

    func promptUser(aboutFlow flowInfo: [String: String], responseHandler: @escaping (Bool) -> Void) {
        
        os_log("Got a promptUser call, flow info: %@", flowInfo)
        
        guard let localPort = flowInfo[FlowInfoKey.localPort.rawValue],
              let remoteAddress = flowInfo[FlowInfoKey.remoteAddress.rawValue],
          
        let window = view.window else {
            os_log("Got a promptUser call without valid flow info: %@", flowInfo)
            responseHandler(true)
            return
        }

        let connectionDate = Date()

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "New incoming connection"
            alert.informativeText = "A new connection on port \(localPort) has been received from \(remoteAddress)."
            alert.addButton(withTitle: "Allow")
            alert.addButton(withTitle: "Deny")

            alert.beginSheetModal(for: window) { userResponse in
                let userAllowed = (userResponse == .alertFirstButtonReturn)
                self.logFlow(flowInfo, at: connectionDate, userAllowed: userAllowed)
                responseHandler(userAllowed)
            }
        }
    }
}
*/
