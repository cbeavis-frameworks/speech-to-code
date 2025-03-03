//
//  ProcessRunner.swift
//  SpeechToCode
//
//  Created on: 2025-03-03
//

import Foundation
import OSLog

/// Utility class to run external processes
class ProcessRunner {
    /// Result of running a process
    struct ProcessResult {
        let stdout: String
        let stderr: String
        let exitCode: Int32
        
        /// Whether the process completed successfully
        var succeeded: Bool {
            return exitCode == 0
        }
        
        /// Whether the process failed
        var failed: Bool {
            return !succeeded
        }
    }
    
    /// Run an external process and return its result
    /// - Parameters:
    ///   - executableURL: URL to the executable
    ///   - arguments: Arguments to pass to the process
    ///   - currentDirectoryPath: Optional working directory
    ///   - environment: Optional environment variables
    ///   - timeout: Optional timeout in seconds
    /// - Returns: Process result including stdout, stderr, and exit code
    static func run(
        _ executablePath: String,
        arguments: [String],
        currentDirectoryPath: String? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) async -> ProcessResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        // Configure executable and arguments
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        
        // Configure working directory if specified
        if let dirPath = currentDirectoryPath {
            process.currentDirectoryURL = URL(fileURLWithPath: dirPath)
        }
        
        // Configure environment variables if specified
        if let environment = environment {
            var processEnvironment = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                processEnvironment[key] = value
            }
            process.environment = processEnvironment
        }
        
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        do {
            try process.run()
            
            // Handle timeout if specified
            if let timeout = timeout {
                return await withCheckedContinuation { continuation in
                    // Create a background task for the timeout
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        if process.isRunning {
                            AppLogger.log(AppLogger.process, level: .warning, message: "Process timed out after \(timeout) seconds")
                            process.terminate()
                            
                            // Get any output that might be available
                            let stdoutData = try? stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
                            let stderrData = try? stderrPipe.fileHandleForReading.readToEnd() ?? Data()
                            
                            let stdout = String(decoding: stdoutData ?? Data(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                            let stderr = String(decoding: stderrData ?? Data(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            continuation.resume(returning: ProcessResult(
                                stdout: stdout,
                                stderr: "Process timed out after \(timeout) seconds. Partial stderr: \(stderr)",
                                exitCode: -1
                            ))
                        }
                    }
                    
                    // Create a background task for normal process completion
                    Task {
                        process.waitUntilExit()
                        
                        if !Task.isCancelled {
                            let stdoutData = try? stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
                            let stderrData = try? stderrPipe.fileHandleForReading.readToEnd() ?? Data()
                            
                            let stdout = String(decoding: stdoutData ?? Data(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                            let stderr = String(decoding: stderrData ?? Data(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Log only critical details, not full output
                            let exitCode = process.terminationStatus
                            if exitCode != 0 {
                                AppLogger.log(AppLogger.process, level: .error, message: "Process failed with exit code: \(exitCode)")
                            }
                            
                            continuation.resume(returning: ProcessResult(
                                stdout: stdout,
                                stderr: stderr,
                                exitCode: exitCode
                            ))
                        }
                    }
                }
            } else {
                // No timeout, wait for completion normally
                process.waitUntilExit()
                
                let stdoutData = try stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
                let stderrData = try stderrPipe.fileHandleForReading.readToEnd() ?? Data()
                
                let stdout = String(decoding: stdoutData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                let stderr = String(decoding: stderrData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Log only critical details, not full output
                let exitCode = process.terminationStatus
                if exitCode != 0 {
                    AppLogger.log(AppLogger.process, level: .error, message: "Process failed with exit code: \(exitCode)")
                }
                
                return ProcessResult(
                    stdout: stdout,
                    stderr: stderr,
                    exitCode: exitCode
                )
            }
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
