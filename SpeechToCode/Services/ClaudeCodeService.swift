//
//  ClaudeCodeService.swift
//  SpeechToCode
//
//  Created on: 2025-03-04
//

import Foundation
import Combine
import OSLog

/// Service for interacting with the Claude Code CLI
class ClaudeCodeService: ObservableObject {
    /// Current terminal output from Claude Code
    @Published var terminalOutput: String = ""
    
    /// Indicates if the service is currently processing a request
    @Published var isProcessing: Bool = false
    
    /// Error message, if any
    @Published var errorMessage: String?
    
    /// Path to the bin directory containing Node.js executables
    private var nodeBinPath: String?
    
    /// Initialize the service with the path to the bin directory containing Node.js executables
    /// - Parameter nodeBinPath: Path to the directory containing node, npm, and npx executables
    init(nodeBinPath: String? = nil) {
        self.nodeBinPath = nodeBinPath
    }
    
    /// Prepare environment variables for running Node.js executables
    /// - Returns: Environment dictionary with PATH and NODE variables set
    private func prepareEnvironment() -> [String: String]? {
        guard let binDir = nodeBinPath, !binDir.isEmpty else {
            return nil
        }
        
        // Create a modified environment with the bin directory in the PATH
        var env = ProcessInfo.processInfo.environment
        
        // Add the bin directory to PATH
        if var path = env["PATH"] {
            // Make sure the bin directory is at the start of PATH
            if !path.contains(binDir) {
                path = "\(binDir):\(path)"
                env["PATH"] = path
            }
        } else {
            env["PATH"] = binDir
        }
        
        // Set the NODE environment variable to the node executable path
        let nodePath = "\(binDir)/node"
        env["NODE"] = nodePath
        
        return env
    }
    
    /// Send a message to Claude Code CLI
    /// - Parameter message: The message to send
    /// - Returns: Success indicator
    @discardableResult
    func sendMessage(_ message: String) async -> Bool {
        guard !message.isEmpty else { return false }
        
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
            // Add the user's message to the terminal output
            terminalOutput += "\n> \(message)\n"
        }
        
        // Make sure we have a valid node bin directory path
        guard let binDir = nodeBinPath, !binDir.isEmpty else {
            await MainActor.run {
                let errorMsg = "Error: Node.js bin directory path is not set"
                errorMessage = errorMsg
                terminalOutput += "\n\(errorMsg)\n"
                terminalOutput += "Please ensure Node.js is properly installed before using Claude Code.\n"
                isProcessing = false
            }
            return false
        }
        
        // Define the npx path based on the node bin directory
        let npxPath = "\(binDir)/npx"
        
        // Check if the npx executable exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: npxPath) else {
            await MainActor.run {
                let errorMsg = "Error: npx executable not found at \(npxPath)"
                errorMessage = errorMsg
                terminalOutput += "\n\(errorMsg)\n"
                terminalOutput += "Please ensure Node.js is correctly installed with npx available.\n"
                isProcessing = false
            }
            return false
        }
        
        // Prepare environment with proper PATH setting
        guard let environment = prepareEnvironment() else {
            await MainActor.run {
                let errorMsg = "Error: Unable to prepare environment variables"
                errorMessage = errorMsg
                terminalOutput += "\n\(errorMsg)\n"
                isProcessing = false
            }
            return false
        }
        
        // Run Claude Code CLI with the user's message
        let result = await ProcessRunner.run(
            npxPath,
            arguments: ["@anthropic-ai/claude-code", message],
            environment: environment
        )
        
        // Update the terminal output with Claude's response
        await MainActor.run {
            terminalOutput += "\n" + result.stdout
            isProcessing = false
        }
        
        return true
    }
    
    /// Clear the terminal output
    func clearTerminal() {
        terminalOutput = ""
        errorMessage = nil
    }
    
    /// Check if Claude Code CLI is installed and working
    /// - Returns: True if Claude Code is working, false otherwise
    @discardableResult
    func checkClaudeCodeInstallation() async -> Bool {
        await MainActor.run {
            isProcessing = true
            terminalOutput += "\nChecking Claude Code installation...\n"
        }
        
        // Make sure we have a valid node bin directory path
        guard let binDir = nodeBinPath, !binDir.isEmpty else {
            await MainActor.run {
                let errorMsg = "Error: Node.js bin directory path is not set"
                errorMessage = errorMsg
                terminalOutput += "\(errorMsg)\n"
                terminalOutput += "Please ensure Node.js is properly installed before using Claude Code.\n"
                isProcessing = false
            }
            return false
        }
        
        // Define the npx path based on the node bin directory
        let npxPath = "\(binDir)/npx"
        
        await MainActor.run {
            terminalOutput += "Using npx at: \(npxPath)\n"
        }
        
        // Check if the npx executable exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: npxPath) else {
            await MainActor.run {
                let errorMsg = "Error: npx executable not found at \(npxPath)"
                errorMessage = errorMsg
                terminalOutput += "\(errorMsg)\n"
                terminalOutput += "Please ensure Node.js is correctly installed with npx available.\n"
                isProcessing = false
            }
            return false
        }
        
        // Make sure node executable exists too
        let nodePath = "\(binDir)/node"
        if !fileManager.fileExists(atPath: nodePath) {
            await MainActor.run {
                let errorMsg = "Error: node executable not found at \(nodePath)"
                errorMessage = errorMsg
                terminalOutput += "\(errorMsg)\n"
                terminalOutput += "Please ensure Node.js is correctly installed.\n"
                isProcessing = false
            }
            return false
        }
        
        // Prepare environment with proper PATH setting
        guard let environment = prepareEnvironment() else {
            await MainActor.run {
                let errorMsg = "Error: Unable to prepare environment variables"
                errorMessage = errorMsg
                terminalOutput += "\(errorMsg)\n"
                isProcessing = false
            }
            return false
        }
        
        await MainActor.run {
            terminalOutput += "Using node at: \(nodePath)\n"
            terminalOutput += "PATH environment includes: \(environment["PATH"] ?? "unknown")\n"
        }
        
        // Check if the Claude Code package is installed
        let checkPackageResult = await ProcessRunner.run(
            npxPath,
            arguments: ["--no-install", "which", "@anthropic-ai/claude-code"],
            environment: environment
        )
        
        // If the package is not found, we need to install it
        if !checkPackageResult.succeeded || checkPackageResult.stdout.isEmpty {
            await MainActor.run {
                terminalOutput += "Claude Code package not found. Attempting to install...\n"
            }
            
            // Install Claude Code package
            let installResult = await ProcessRunner.run(
                npxPath,
                arguments: ["npm", "install", "-g", "@anthropic-ai/claude-code"],
                environment: environment
            )
            
            if !installResult.succeeded {
                await MainActor.run {
                    terminalOutput += "Failed to install Claude Code package.\n"
                    if !installResult.stderr.isEmpty {
                        terminalOutput += "Error: \(installResult.stderr)\n"
                    }
                    errorMessage = "Failed to install Claude Code package"
                    isProcessing = false
                }
                return false
            }
            
            await MainActor.run {
                terminalOutput += "Claude Code package installed successfully.\n"
            }
        }
        
        // Run a simple test command with Claude Code
        let result = await ProcessRunner.run(
            npxPath,
            arguments: ["@anthropic-ai/claude-code", "--version"],
            environment: environment
        )
        
        let isWorking = !result.stdout.isEmpty && result.succeeded
        
        await MainActor.run {
            if isWorking {
                terminalOutput += "Claude Code is installed and working. Version: \(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            } else {
                terminalOutput += "Claude Code installation check failed.\n"
                if !result.stderr.isEmpty {
                    terminalOutput += "Error: \(result.stderr)\n"
                }
                errorMessage = "Claude Code installation check failed"
            }
            isProcessing = false
        }
        
        return isWorking
    }
}
