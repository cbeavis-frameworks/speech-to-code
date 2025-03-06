import Foundation
import Combine
import AppKit

class TerminalController: ObservableObject {
    @Published var terminalOutput: String = ""
    @Published var isConnected: Bool = false
    @Published var summary: String = ""
    @Published var permissionStatus: PermissionStatus = .unknown
    @Published var isInteractiveMode: Bool = false
    @Published var isClaudeMode: Bool = false
    @Published var claudeCommandHistory: [String] = []
    @Published var lastClaudeResponse: String = ""
    
    private var outputBuffer: String = ""
    private var cancellables = Set<AnyCancellable>()
    private var pollingTimer: Timer?
    private var lastTerminalContent: String = ""
    let helperScriptPath = "/Users/chrisbeavis/Desktop/SpeechToCode/terminal_helper.sh"
    
    enum PermissionStatus {
        case unknown
        case granted
        case denied
        case notDetermined
    }
    
    // Connect to Terminal.app
    func connectToTerminal() {
        // First check if Terminal.app is running
        if !isTerminalRunning() {
            // Launch Terminal if it's not running
            NSWorkspace.shared.launchApplication("Terminal")
            
            // Wait a moment for Terminal to launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startPollingTerminal()
            }
        } else {
            startPollingTerminal()
        }
        
        isConnected = true
        permissionStatus = .granted
        
        DispatchQueue.main.async {
            self.terminalOutput = "Connected to Terminal.app\n"
        }
    }
    
    // Check if Terminal.app is running
    private func isTerminalRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == "com.apple.Terminal" }
    }
    
    // Start polling Terminal.app for changes
    private func startPollingTerminal() {
        // First, get the initial content
        readTerminalContent()
        
        // Then set up the timer for polling
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.readTerminalContent()
        }
    }
    
    // Read content from Terminal.app using the helper script
    private func readTerminalContent() {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [helperScriptPath, "read_content"]
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let content = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                // Check for interactive prompts
                checkForInteractivePrompts(content)
                
                // Check for Claude prompts
                detectClaudePrompt(content)
                
                if content != lastTerminalContent {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        // Only append the new content
                        if !self.lastTerminalContent.isEmpty {
                            let newContent = self.extractNewContent(oldContent: self.lastTerminalContent, newContent: content)
                            if !newContent.isEmpty {
                                self.terminalOutput += newContent
                                self.outputBuffer += newContent
                                
                                // If in Claude mode, parse the response
                                if self.isClaudeMode {
                                    self.parseClaudeResponse(newContent)
                                }
                            }
                        } else {
                            self.terminalOutput = content
                            self.outputBuffer = content
                        }
                        
                        self.lastTerminalContent = content
                        
                        // Periodically summarize the output
                        if self.outputBuffer.count > 500 {
                            self.summarizeOutput()
                            self.outputBuffer = ""
                        }
                    }
                }
            }
        } catch {
            print("Error reading terminal content: \(error)")
        }
    }
    
    // Check for interactive prompts in the terminal output
    private func checkForInteractivePrompts(_ content: String) {
        // Common patterns that indicate interactive prompts
        let interactivePatterns = [
            "Do you want to proceed?",
            "[y/n]",
            "(y/n)",
            "Select an option:",
            "Press any key to continue",
            "Press Enter to continue",
            "to continue…"
        ]
        
        let isInteractive = interactivePatterns.contains { pattern in
            content.contains(pattern)
        }
        
        DispatchQueue.main.async {
            self.isInteractiveMode = isInteractive
        }
    }
    
    // Detect Claude Code CLI prompts
    public func detectClaudePrompt(_ content: String) {
        // Claude CLI specific patterns
        let claudeInteractivePatterns = [
            "Claude Code",
            "> ",
            "/bug",
            "/clear",
            "/compact",
            "/config",
            "/cost",
            "/doctor",
            "/help",
            "/init",
            "/login",
            "/logout",
            "/pr_comments",
            "/review",
            "/terminal-setup"
        ]
        
        let isClaudePrompt = claudeInteractivePatterns.contains { pattern in
            content.contains(pattern)
        }
        
        DispatchQueue.main.async {
            self.isClaudeMode = isClaudePrompt
            if isClaudePrompt {
                self.isInteractiveMode = true
            }
        }
    }
    
    // Extract only the new content by comparing old and new
    private func extractNewContent(oldContent: String, newContent: String) -> String {
        if newContent.hasPrefix(oldContent) {
            return String(newContent.dropFirst(oldContent.count))
        }
        
        // If we can't do a simple prefix match, try to find where they diverge
        let oldLines = oldContent.components(separatedBy: .newlines)
        let newLines = newContent.components(separatedBy: .newlines)
        
        var divergeIndex = 0
        let minCount = min(oldLines.count, newLines.count)
        
        while divergeIndex < minCount && oldLines[divergeIndex] == newLines[divergeIndex] {
            divergeIndex += 1
        }
        
        if divergeIndex < newLines.count {
            return newLines[divergeIndex...].joined(separator: "\n")
        }
        
        return ""
    }
    
    // Send a command to Terminal.app using the helper script
    func sendCommand(_ command: String) {
        guard isConnected else { return }
        
        // Escape quotes in the command to avoid shell errors
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [helperScriptPath, "send_command", escapedCommand]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                DispatchQueue.main.async {
                    self.terminalOutput += "> \(command)\n"
                }
            } else {
                DispatchQueue.main.async {
                    self.terminalOutput += "Error sending command: \(command)\n"
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.terminalOutput += "Error: \(error.localizedDescription)\n"
            }
        }
    }
    
    // Send a Claude-specific command to Terminal.app
    func sendClaudeCommand(_ command: String, options: String = "") {
        guard isConnected else { return }
        
        // Track command in history
        trackClaudeCommand(command)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [helperScriptPath, "claude_command", command, options]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                DispatchQueue.main.async {
                    self.terminalOutput += "> claude \"\(command)\"\n"
                }
            } else {
                DispatchQueue.main.async {
                    self.terminalOutput += "Error sending Claude command: \(command)\n"
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.terminalOutput += "Error: \(error.localizedDescription)\n"
            }
        }
    }
    
    // Track Claude commands in history
    func trackClaudeCommand(_ command: String) {
        DispatchQueue.main.async {
            self.claudeCommandHistory.append(command)
            
            // Keep history at a reasonable size
            if self.claudeCommandHistory.count > 50 {
                self.claudeCommandHistory.removeFirst()
            }
        }
    }
    
    // Parse Claude's response to extract structured information
    func parseClaudeResponse(_ response: String) {
        // Store the raw response
        lastClaudeResponse = response
        
        // Extract code blocks
        let codeBlockPattern = #"```(?:\w+)?\s*\n([\s\S]*?)\n```"#
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern) {
            let nsString = response as NSString
            let matches = regex.matches(in: response, range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                if match.numberOfRanges > 1 {
                    let codeRange = match.range(at: 1)
                    let code = nsString.substring(with: codeRange)
                    print("Extracted code block: \(code)")
                    // You could store these code blocks in an array if needed
                }
            }
        }
    }
    
    // Initialize Claude CLI in the current directory
    func initializeClaudeCLI() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [helperScriptPath, "handle_claude", "init"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                DispatchQueue.main.async {
                    self.isClaudeMode = true
                    self.terminalOutput += "Claude CLI initialized\n"
                }
            } else {
                DispatchQueue.main.async {
                    self.terminalOutput += "Error initializing Claude CLI\n"
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.terminalOutput += "Error: \(error.localizedDescription)\n"
            }
        }
    }
    
    // Execute a Claude slash command
    func executeClaudeSlashCommand(_ command: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [helperScriptPath, "handle_claude", "slash_command", command]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                DispatchQueue.main.async {
                    self.terminalOutput += "> /\(command)\n"
                }
            } else {
                DispatchQueue.main.async {
                    self.terminalOutput += "Error executing Claude slash command: \(command)\n"
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.terminalOutput += "Error: \(error.localizedDescription)\n"
            }
        }
    }
    
    // Interrupt Claude if it's processing
    func interruptClaude() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [helperScriptPath, "handle_claude", "interrupt"]
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Error interrupting Claude: \(error)")
        }
    }
    
    // Send a specific keystroke for interactive prompts
    func sendKeystroke(_ key: String) {
        guard isConnected else { return }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [helperScriptPath, "send_keystroke", key]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                DispatchQueue.main.async {
                    self.terminalOutput += "> [Keystroke: \(key)]\n"
                }
            } else {
                DispatchQueue.main.async {
                    self.terminalOutput += "Error sending keystroke: \(key)\n"
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.terminalOutput += "Error: \(error.localizedDescription)\n"
            }
        }
    }
    
    // Convenience methods for common keystrokes
    func sendYes() {
        sendKeystroke("y")
    }
    
    func sendNo() {
        sendKeystroke("n")
    }
    
    func sendUp() {
        sendKeystroke("up")
    }
    
    func sendDown() {
        sendKeystroke("down")
    }
    
    func sendEnter() {
        sendKeystroke("enter")
    }
    
    func sendEscape() {
        sendKeystroke("escape")
    }
    
    // Open Terminal.app
    func openTerminal() {
        NSWorkspace.shared.launchApplication("Terminal")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.connectToTerminal()
        }
    }
    
    // Summarize the terminal output
    private func summarizeOutput() {
        // Split the output into lines
        let lines = outputBuffer.components(separatedBy: .newlines)
        
        // Extract command and result patterns
        var lastCommand = ""
        var commandResults: [String: String] = [:]
        var currentCommandOutput = ""
        
        for line in lines {
            // Check if line looks like a command (starts with a prompt)
            if line.contains("$ ") || line.contains("> ") {
                // If we had a previous command, store its output
                if !lastCommand.isEmpty {
                    commandResults[lastCommand] = currentCommandOutput
                }
                
                // Extract the new command
                if let commandPart = line.split(separator: "$ ").last ?? line.split(separator: "> ").last {
                    lastCommand = String(commandPart)
                    currentCommandOutput = ""
                }
            } else if !lastCommand.isEmpty {
                // Add to the current command's output
                currentCommandOutput += line + " "
            }
        }
        
        // Add the last command's output
        if !lastCommand.isEmpty {
            commandResults[lastCommand] = currentCommandOutput
        }
        
        // Create a summary
        var summaryText = "Terminal Activity Summary:\n"
        
        if commandResults.isEmpty {
            summaryText += "No commands detected in recent output.\n"
        } else {
            for (command, output) in commandResults {
                let truncatedOutput = output.count > 100 ? output.prefix(100) + "..." : output
                summaryText += "• Command: \(command)\n"
                summaryText += "  Result: \(truncatedOutput)\n\n"
            }
        }
        
        // Update the summary property
        DispatchQueue.main.async {
            self.summary = summaryText
        }
    }
    
    // Disconnect from Terminal.app
    func disconnectFromTerminal() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isConnected = false
    }
    
    deinit {
        disconnectFromTerminal()
        cancellables.forEach { $0.cancel() }
    }
}
