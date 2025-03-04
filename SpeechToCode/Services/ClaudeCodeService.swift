//
//  ClaudeCodeService.swift
//  SpeechToCode
//
//  Created on: 2025-03-04
//

import Foundation
import Combine

/// Service for interacting with the Claude Code CLI
class ClaudeCodeService: ObservableObject {
    /// Current terminal output from Claude Code
    @Published var terminalOutput: String = ""
    
    /// Indicates if the service is currently processing a request
    @Published var isProcessing: Bool = false
    
    /// Error message, if any
    @Published var errorMessage: String?
    
    /// The Node.js installation directory
    private var nodeDirectory: String?
    
    /// Initialize the service with the Node.js installation directory
    init(nodeDirectory: String? = nil) {
        self.nodeDirectory = nodeDirectory
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
        
        // Determine the correct path to npx
        let claudeCommandPath: String
        if let nodeDir = nodeDirectory, !nodeDir.isEmpty {
            claudeCommandPath = "\(nodeDir)/npx"
            await MainActor.run {
                terminalOutput += "\nUsing npx at: \(claudeCommandPath)\n"
            }
        } else {
            // Use system-wide npx if available
            claudeCommandPath = "/usr/local/bin/npx"
            await MainActor.run {
                terminalOutput += "\nFalling back to default npx at: \(claudeCommandPath)\n"
            }
        }
        
        // Check if the file exists before attempting to run
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: claudeCommandPath) else {
            await MainActor.run {
                let errorMsg = "Error: npx executable not found at \(claudeCommandPath)"
                errorMessage = errorMsg
                terminalOutput += "\n\(errorMsg)\n"
                isProcessing = false
            }
            return false
        }
        
        // Run Claude Code CLI with the user's message
        let result = await ProcessRunner.run(
            claudeCommandPath,
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
        
        // Determine the correct path to npx
        let claudeCommandPath: String
        if let nodeDir = nodeDirectory, !nodeDir.isEmpty {
            claudeCommandPath = "\(nodeDir)/npx"
            await MainActor.run {
                terminalOutput += "Using npx at: \(claudeCommandPath)\n"
            }
        } else {
            // Try to find npx in common locations
            let possiblePaths = [
                "/usr/local/bin/npx",
                "/opt/homebrew/bin/npx",
                "/usr/bin/npx",
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".nvm/versions/node/v18.17.0/bin/npx").path
            ]
            
            let foundPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) }
            
            claudeCommandPath = foundPath ?? "/usr/local/bin/npx"
            await MainActor.run {
                terminalOutput += "Falling back to npx at: \(claudeCommandPath)\n"
            }
        }
        
        // Check if the file exists before attempting to run
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: claudeCommandPath) else {
            await MainActor.run {
                let errorMsg = "Error: npx executable not found at \(claudeCommandPath)"
                errorMessage = errorMsg
                terminalOutput += "\(errorMsg)\n"
                isProcessing = false
            }
            return false
        }
        
        // Run a simple test command with Claude Code
        let result = await ProcessRunner.run(
            claudeCommandPath,
            arguments: ["@anthropic-ai/claude-code", "--version"],
            environment: nil
        )
        
        let isWorking = !result.stdout.isEmpty
        
        await MainActor.run {
            if isWorking {
                terminalOutput += "Claude Code is installed and working. Version: \(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            } else {
                terminalOutput += "Claude Code installation check failed.\n"
                errorMessage = "Claude Code installation check failed"
            }
            isProcessing = false
        }
        
        return isWorking
    }
}
