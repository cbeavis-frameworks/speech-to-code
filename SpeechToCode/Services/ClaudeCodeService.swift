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
    func sendMessage(_ message: String) async -> Bool {
        guard !message.isEmpty else { return false }
        
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
            // Add the user's message to the terminal output
            terminalOutput += "\n> \(message)\n"
        }
        
        do {
            let claudeCommandPath = (nodeDirectory?.isEmpty ?? true) ? "npx" : "\(nodeDirectory!)/npx"
            
            // Run Claude Code CLI with the user's message
            let result = try await ProcessRunner.run(
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
        } catch {
            await MainActor.run {
                errorMessage = "Error: \(error.localizedDescription)"
                terminalOutput += "\nError: \(error.localizedDescription)\n"
                isProcessing = false
            }
            return false
        }
    }
    
    /// Clear the terminal output
    func clearTerminal() {
        terminalOutput = ""
        errorMessage = nil
    }
    
    /// Check if Claude Code CLI is installed and working
    /// - Returns: True if Claude Code is working, false otherwise
    func checkClaudeCodeInstallation() async -> Bool {
        await MainActor.run {
            isProcessing = true
            terminalOutput += "\nChecking Claude Code installation...\n"
        }
        
        do {
            let claudeCommandPath = (nodeDirectory?.isEmpty ?? true) ? "npx" : "\(nodeDirectory!)/npx"
            
            // Run a simple test command with Claude Code
            let result = try await ProcessRunner.run(
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
        } catch {
            await MainActor.run {
                errorMessage = "Error checking Claude Code: \(error.localizedDescription)"
                terminalOutput += "Error checking Claude Code: \(error.localizedDescription)\n"
                isProcessing = false
            }
            return false
        }
    }
}
