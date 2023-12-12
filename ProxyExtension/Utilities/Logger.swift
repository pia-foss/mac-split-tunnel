import Puppy
import Foundation

class Logger {
    static var log : Puppy = Puppy()
}

func initializeLogger(options: [String : Any]?) -> Bool {
    guard let logLevel = options!["logLevel"] as? String else {
        return false
    }
    
    // Initialize the Console logger first
    let console = ConsoleLogger(Bundle.main.bundleIdentifier! + ".console", logLevel: logLevelFromString(logLevel))
    Logger.log.add(console)
    
    guard let logFile = options!["logFile"] as? String else {
        Logger.log.error("Error: Cannot find logFile in options")
        return false
    }
    
    // Now configure the File logger
    let fileURL = URL(fileURLWithPath: logFile).absoluteURL

    do {
        let file = try FileLogger("com.privateinternetaccess.splittunnel.poc.extension.systemextension.logfile",
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

func log(_ type:LogLevel, _ text: String) {
    let currentDate = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss:SSSS"
    let currentTimeString = formatter.string(from: currentDate)
    
    switch type {
    case .debug:
        Logger.log.debug("[\(currentTimeString)] debug: \(text)")
    case .info:
        Logger.log.info("[\(currentTimeString)] info: \(text)")
    case .warning:
        Logger.log.warning("[\(currentTimeString)] warning: \(text)")
    case .error:
        Logger.log.error("[\(currentTimeString)] error: \(text)")
    default:
        Logger.log.info("[\(currentTimeString)] info: \(text)")
    }
}
