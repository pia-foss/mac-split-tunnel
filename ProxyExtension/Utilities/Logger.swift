import Puppy
import Foundation

protocol LoggerProtocol {
    func initializeLogger(logLevel: String, logFile: String) -> Bool
    func logLevelFromString(_ levelString: String) -> LogLevel
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

class Logger: LoggerProtocol {
    static var instance: LoggerProtocol = Logger()

    // Private implementation
    var pimpl = Puppy()

    func initializeLogger(logLevel: String, logFile: String) -> Bool {
        // Initialize the Console logger first
        let console = ConsoleLogger(Bundle.main.bundleIdentifier! + ".console", logLevel: logLevelFromString(logLevel))
        pimpl.add(console)

        // Now configure the File logger
        let fileURL = URL(fileURLWithPath: logFile).absoluteURL

        do {
            let file = try FileLogger("com.privateinternetaccess.vpn.splittunnel.systemextension.logfile",
                                      logLevel: logLevelFromString(logLevel),
                                      fileURL: fileURL,
                                      filePermission: "777")
            pimpl.add(file)
        }
        catch {
            warning("Could not start File Logger, will log only to console.")
        }

        info("######################################################\n######################################################\nLogger initialized. Writing to \(fileURL)")

        return true
    }

    func debug(_ message: String) { pimpl.debug(message) }
    func info(_ message: String) { pimpl.info(message) }
    func warning(_ message: String) { pimpl.warning(message) }
    func error(_ message: String) { pimpl.error(message) }

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

