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
        
        // Run Claude Code CLI with the user's message
        let result = await ProcessRunner.run(
            npxPath,
            arguments: ["@anthropic-ai/claude-code", message],
            environment: nil
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
        
        // Run a simple test command with Claude Code
        let result = await ProcessRunner.run(
            npxPath,
            arguments: ["@anthropic-ai/claude-code", "--version"],
            environment: nil
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
