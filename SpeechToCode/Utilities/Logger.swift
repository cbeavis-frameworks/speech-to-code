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
    
    /// Log a message with the given logger and level
    static func log(_ logger: Logger, level: Level, message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let contextInfo = "[\(fileName):\(line) \(function)]"
        
        switch level {
        case .debug:
            logger.debug("\(contextInfo) \(message)")
        case .info:
            logger.info("\(contextInfo) \(message)")
        case .warning:
            logger.warning("\(contextInfo) \(message)")
        case .error:
            logger.error("\(contextInfo) \(message)")
        case .critical:
            logger.critical("\(contextInfo) \(message)")
        }
        
        // Print to console as well to make debugging easier
        let levelString = level.description
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        print("[\(timestamp)] [\(levelString)] \(contextInfo) \(message)")
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
