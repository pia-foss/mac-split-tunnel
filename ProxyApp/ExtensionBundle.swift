import Foundation

// Get the Bundle of the system extension
func getExtensionBundleID() -> Bundle {
    let extensionsDirectoryURL = 
        URL(fileURLWithPath: "Contents/Library/SystemExtensions", relativeTo: Bundle.main.bundleURL)
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
}
