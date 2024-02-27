import Puppy
import Foundation

protocol LoggerProtocol {
    func updateLogger(logLevel: String, logFile: String)
    func logLevelFromString(_ levelString: String) -> LogLevel
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

class Logger: LoggerProtocol {
    static var instance: LoggerProtocol = Logger()

    static let fallbackLogLevel = "error"

    // This will be used if logFile is empty - which implies
    // logging is turned off. We still trace to a temp file however,
    // but this file will not be uploaded or used by PIA
    static let fallbackLogFile = "/tmp/STProxy.log"

    // Private implementation
    var pimpl: Puppy?

    // Make the setters private but getters public
    public private(set) var logFile: String = ""
    public private(set) var logLevel: String = ""

    func updateLogger(logLevel: String, logFile: String) {
        self.logLevel = logLevel.isEmpty ? Logger.fallbackLogLevel : logLevel
        self.logFile = logFile.isEmpty ? Logger.fallbackLogFile : logFile

        // Create a new Puppy instance to replace the existing one (if one exists)
        var newPimpl = Puppy()

        // Initialize the Console logger first
        let console = ConsoleLogger(Bundle.main.bundleIdentifier! + ".console", logLevel: logLevelFromString(self.logLevel))

        // Add the console logger
        newPimpl.add(console)

        // Now configure the File logger
        let fileURL = URL(fileURLWithPath: self.logFile).absoluteURL

        do {
            let file = try FileLogger("com.privateinternetaccess.vpn.splittunnel.systemextension.logfile",
                                      logLevel: logLevelFromString(self.logLevel),
                                      fileURL: fileURL,
                                      filePermission: "777")
            // Add the file logger
            newPimpl.add(file)
        }
        catch {
            warning("Could not start File Logger, will log only to console.")
        }

        info("\nLogger initialized. Writing to \(fileURL) with log level: \(logLevel)")

        // Atomic operation to replace the current pimpl logger with a new one, since
        // this is atomic we don't need to worry about a mutex.
        self.pimpl = newPimpl
    }

    func debug(_ message: String) { pimpl?.debug(message) }
    func info(_ message: String) { pimpl?.info(message) }
    func warning(_ message: String) { pimpl?.warning(message) }
    func error(_ message: String) { pimpl?.error(message) }

    func logLevelFromString(_ levelString: String) -> LogLevel {
        switch levelString.lowercased() {
        case "debug":
            return .debug
        case "info":
            return .info
        case "warning":
            return .warning
        case "error":
            return .error
        default:
            return .error
        }
    }
}

func log(_ type: LogLevel, _ text: String, file: String = #file, line: Int = #line) {
    let currentDate = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSSS"
    let currentTimeString = formatter.string(from: currentDate)
    let fileName = (file as NSString).lastPathComponent // Extracts just the filename

    switch type {
    case .debug:
        Logger.instance.debug("[\(currentTimeString)] [\(fileName):\(line)] debug: \(text)")
    case .info:
        Logger.instance.info("[\(currentTimeString)] [\(fileName):\(line)] info: \(text)")
    case .warning:
        Logger.instance.warning("[\(currentTimeString)] [\(fileName):\(line)] warning: \(text)")
    case .error:
        Logger.instance.error("[\(currentTimeString)] [\(fileName):\(line)] error: \(text)")
    default:
        Logger.instance.info("[\(currentTimeString)] [\(fileName):\(line)] info: \(text)")
    }
}

