//
//  ProcessRunner.swift
//  SpeechToCode
//
//  Created on: 2025-03-03
//

import Foundation
import OSLog

/// A utility for running shell commands and getting their output
class ProcessRunner {
    /// Result of running a process
    struct ProcessResult {
        let stdout: String
        let stderr: String
        let exitCode: Int32
        
        var succeeded: Bool {
            return exitCode == 0
        }
    }
    
    /// Run a shell command and return its output
    /// - Parameters:
    ///   - command: The command to run
    ///   - arguments: Arguments for the command
    ///   - currentDirectoryPath: The directory to run the command in
    ///   - environment: Environment variables to set
    /// - Returns: The result of running the process
    static func run(
        _ command: String,
        arguments: [String] = [],
        currentDirectoryPath: String? = nil,
        environment: [String: String]? = nil
    ) async -> ProcessResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        // Log the command being executed
        let commandArgs = arguments.joined(separator: " ")
        let commandString = "\(command) \(commandArgs)"
        AppLogger.log(AppLogger.process, level: .info, message: "Executing command: \(commandString)")
        
        if let currentDirectoryPath = currentDirectoryPath {
            AppLogger.log(AppLogger.process, level: .debug, message: "Working directory: \(currentDirectoryPath)")
        }
        
        if let environment = environment {
            let envString = environment.map { key, value in "\(key)=\(value)" }.joined(separator: ", ")
            AppLogger.log(AppLogger.process, level: .debug, message: "Environment variables: \(envString)")
        }
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        
        if let currentDirectoryPath = currentDirectoryPath {
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectoryPath)
        }
        
        if let environment = environment {
            // Merge with existing environment
            var processEnvironment = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                processEnvironment[key] = value
            }
            process.environment = processEnvironment
        }
        
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        do {
            AppLogger.log(AppLogger.process, level: .debug, message: "Starting process")
            try process.run()
            
            AppLogger.log(AppLogger.process, level: .debug, message: "Waiting for process to complete")
            process.waitUntilExit()
            
            let stdoutData = try stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
            let stderrData = try stderrPipe.fileHandleForReading.readToEnd() ?? Data()
            
            let stdout = String(decoding: stdoutData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let stderr = String(decoding: stderrData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Log the result
            let exitCode = process.terminationStatus
            AppLogger.log(AppLogger.process, level: exitCode == 0 ? .info : .error, 
                         message: "Process completed with exit code: \(exitCode)")
            
            if !stdout.isEmpty {
                AppLogger.log(AppLogger.process, level: .debug, message: "Standard output: \(stdout)")
            }
            
            if !stderr.isEmpty {
                AppLogger.log(AppLogger.process, level: .warning, message: "Standard error: \(stderr)")
            }
            
            return ProcessResult(
                stdout: stdout,
                stderr: stderr,
                exitCode: exitCode
            )
        } catch {
            AppLogger.log(AppLogger.process, level: .error, message: "Failed to run process: \(error.localizedDescription)")
            return ProcessResult(
                stdout: "",
                stderr: "Failed to run process: \(error.localizedDescription)",
                exitCode: 1
            )
        }
    }
}
