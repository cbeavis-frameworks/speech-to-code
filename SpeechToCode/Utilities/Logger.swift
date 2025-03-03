//
//  Logger.swift
//  SpeechToCode
//
//  Created on: 2025-03-03
//

import Foundation
import OSLog

/// Custom logger for the application
class AppLogger {
    // Create subsystem loggers
    static let installation = Logger(subsystem: "com.SpeechToCode", category: "Installation")
    static let node = Logger(subsystem: "com.SpeechToCode", category: "NodeJS")
    static let claudeCode = Logger(subsystem: "com.SpeechToCode", category: "ClaudeCode")
    static let process = Logger(subsystem: "com.SpeechToCode", category: "Process")
    static let app = Logger(subsystem: "com.SpeechToCode", category: "App")
    
    /// Log levels for more control
    enum Level {
        case debug, info, warning, error, critical
    }
    
    // Flag to enable/disable console printing (in addition to OSLog)
    private static var isConsolePrintingEnabled = false
    
    // Flag to enable/disable file and function context printing
    private static var isVerboseContextEnabled = false
    
    /// Set whether console printing is enabled
    static func enableConsolePrinting(_ enabled: Bool) {
        isConsolePrintingEnabled = enabled
    }
    
    /// Set whether verbose context (file, line, function) is included
    static func enableVerboseContext(_ enabled: Bool) {
        isVerboseContextEnabled = enabled
    }
    
    /// Log a message with the given logger and level
    static func log(_ logger: Logger, level: Level, message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let contextInfo: String
        
        if isVerboseContextEnabled {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            contextInfo = "[\(fileName):\(line) \(function)]"
        } else {
            contextInfo = ""
        }
        
        let finalMessage = isVerboseContextEnabled ? "\(contextInfo) \(message)" : message
        
        switch level {
        case .debug:
            logger.debug("\(finalMessage)")
        case .info:
            logger.info("\(finalMessage)")
        case .warning:
            logger.warning("\(finalMessage)")
        case .error:
            logger.error("\(finalMessage)")
        case .critical:
            logger.critical("\(finalMessage)")
        }
        
        // Print to console only if enabled
        if isConsolePrintingEnabled {
            let levelString = level.description
            let timestamp = Date().formatted(date: .omitted, time: .standard)
            print("[\(timestamp)] [\(levelString)] \(finalMessage)")
        }
    }
}

// Extension to give string representation of log levels
extension AppLogger.Level: CustomStringConvertible {
    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING" 
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
}
