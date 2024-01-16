import Puppy
import Foundation

struct Logger {
    static var log : Puppy = Puppy()

    static func initializeLogger(logLevel: String, logFile: String) -> Bool {
        // Initialize the Console logger first
        let console = ConsoleLogger(Bundle.main.bundleIdentifier! + ".console", logLevel: logLevelFromString(logLevel))
        Logger.log.add(console)

        // Now configure the File logger
        let fileURL = URL(fileURLWithPath: logFile).absoluteURL

        do {
            let file = try FileLogger("com.privateinternetaccess.vpn.splittunnel.systemextension.logfile",
                                      logLevel: logLevelFromString(logLevel),
                                      fileURL: fileURL,
                                      filePermission: "777")
            Logger.log.add(file)
        }
        catch {
            Logger.log.warning("Could not start File Logger, will log only to console.")
        }
        Logger.log.info("######################################################\n######################################################\nLogger initialized. Writing to \(fileURL)")

        return true
    }

    static func logLevelFromString(_ levelString: String) -> LogLevel {
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
    formatter.dateFormat = "HH:mm:ss:SSSS"
    let currentTimeString = formatter.string(from: currentDate)
    let fileName = (file as NSString).lastPathComponent // Extracts just the filename

    switch type {
    case .debug:
        Logger.log.debug("[\(currentTimeString)] [\(fileName):\(line)] debug: \(text)")
    case .info:
        Logger.log.info("[\(currentTimeString)] [\(fileName):\(line)] info: \(text)")
    case .warning:
        Logger.log.warning("[\(currentTimeString)] [\(fileName):\(line)] warning: \(text)")
    case .error:
        Logger.log.error("[\(currentTimeString)] [\(fileName):\(line)] error: \(text)")
    default:
        Logger.log.info("[\(currentTimeString)] [\(fileName):\(line)] info: \(text)")
    }
}

