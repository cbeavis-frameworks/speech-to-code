import Foundation
import Combine

/// Helper class for interacting with Claude Code CLI
class ClaudeHelper: ObservableObject {
    @Published var isClaudeInitialized: Bool = false
    @Published var lastResponse: String = ""
    @Published var commandHistory: [String] = []
    
    private var terminalController: TerminalController
    private var cancellables = Set<AnyCancellable>()
    
    init(terminalController: TerminalController) {
        self.terminalController = terminalController
        
        // Subscribe to terminal output to detect Claude responses
        terminalController.$terminalOutput
            .sink { [weak self] output in
                self?.processTerminalOutput(output)
            }
            .store(in: &cancellables)
    }
    
    /// Initialize Claude CLI in the current directory
    func initializeClaudeCLI() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [terminalController.helperScriptPath, "handle_claude", "init"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                isClaudeInitialized = true
                print("Claude CLI initialized successfully")
            } else {
                print("Error initializing Claude CLI")
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Format and send a prompt to Claude
    func formatClaudePrompt(_ prompt: String, options: String = "") -> String {
        // Track command in history
        trackClaudeCommand(prompt)
        
        // Execute the command
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [terminalController.helperScriptPath, "claude_command", prompt, options]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let result = String(data: data, encoding: .utf8) {
                return result
            }
        } catch {
            print("Error sending Claude prompt: \(error)")
        }
        
        return ""
    }
    
    /// Track Claude commands in history
    func trackClaudeCommand(_ command: String) {
        commandHistory.append(command)
        
        // Keep history at a reasonable size
        if commandHistory.count > 50 {
            commandHistory.removeFirst()
        }
    }
    
    /// Handle Claude response by parsing and extracting relevant information
    func handleClaudeResponse(_ response: String) -> ParsedClaudeResponse {
        // Store the raw response
        lastResponse = response
        
        // Parse the response
        return parseClaudeResponse(response)
    }
    
    /// Parse Claude's response to extract structured information
    func parseClaudeResponse(_ response: String) -> ParsedClaudeResponse {
        var parsedResponse = ParsedClaudeResponse()
        
        // Check for code blocks
        let codeBlockPattern = #"```(?:\w+)?\s*\n([\s\S]*?)\n```"#
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern) {
            let nsString = response as NSString
            let matches = regex.matches(in: response, range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                if match.numberOfRanges > 1 {
                    let codeRange = match.range(at: 1)
                    let code = nsString.substring(with: codeRange)
                    parsedResponse.codeBlocks.append(code)
                }
            }
        }
        
        // Check for function calls
        if response.contains("function_call") || response.contains("tool_call") {
            parsedResponse.containsFunctionCall = true
        }
        
        // Extract main text (excluding code blocks)
        let cleanedResponse = response.replacingOccurrences(
            of: #"```(?:\w+)?\s*\n[\s\S]*?\n```"#,
            with: "[CODE BLOCK]",
            options: .regularExpression
        )
        parsedResponse.mainText = cleanedResponse
        
        return parsedResponse
    }
    
    /// Execute a Claude slash command
    func executeSlashCommand(_ command: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [terminalController.helperScriptPath, "handle_claude", "slash_command", command]
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Error executing slash command: \(error)")
        }
    }
    
    /// Interrupt Claude if it's processing
    func interruptClaude() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [terminalController.helperScriptPath, "handle_claude", "interrupt"]
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Error interrupting Claude: \(error)")
        }
    }
    
    /// Process terminal output to detect and handle Claude responses
    private func processTerminalOutput(_ output: String) {
        // Check if output contains Claude prompt
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [terminalController.helperScriptPath, "detect_claude_prompt"]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if result == "claude_prompt_detected" {
                    // Claude is waiting for input
                    terminalController.isInteractiveMode = true
                }
            }
        } catch {
            print("Error detecting Claude prompt: \(error)")
        }
    }
}

/// Structured representation of a parsed Claude response
struct ParsedClaudeResponse {
    var mainText: String = ""
    var codeBlocks: [String] = []
    var containsFunctionCall: Bool = false
}
