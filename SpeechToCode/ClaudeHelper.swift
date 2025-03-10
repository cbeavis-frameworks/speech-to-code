import Foundation
import Combine

/// Helper class for interacting with Claude Code CLI
class ClaudeHelper: ObservableObject {
    @Published var isClaudeInitialized: Bool = false
    @Published var lastResponse: String = ""
    @Published var commandHistory: [String] = []
    @Published var sessionStatus: ClaudeSessionStatus = .unknown
    @Published var isAuthenticated: Bool = false
    @Published var isProcessing: Bool = false
    @Published var isInstalled: Bool = false
    
    private var terminalController: TerminalController
    private var cancellables = Set<AnyCancellable>()
    private var config: ClaudeConfig?
    
    init(terminalController: TerminalController) {
        self.terminalController = terminalController
        
        // Subscribe to terminal output to detect Claude responses
        terminalController.$terminalOutput
            .sink { [weak self] output in
                self?.processTerminalOutput(output)
            }
            .store(in: &cancellables)
            
        // Check if Claude is installed and authenticated
        checkClaudeSetup()
    }
    
    /// Check if Claude CLI is installed and properly set up
    func checkClaudeSetup() {
        checkClaudeInstallation { [weak self] isInstalled in
            guard let self = self else { return }
            
            if isInstalled {
                self.sessionStatus = .notAuthenticated
                self.checkClaudeAuthentication { isAuthenticated in
                    self.isAuthenticated = isAuthenticated
                    if isAuthenticated {
                        print("Claude CLI is installed and authenticated")
                    } else {
                        print("Claude CLI is installed but not authenticated")
                    }
                }
            } else {
                self.sessionStatus = .notInstalled
                print("Claude CLI is not installed")
            }
        }
    }
    
    /// Check if Claude CLI is installed
    func checkClaudeInstallation(completion: @escaping (Bool) -> Void) {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["claude"]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async {
                    self.isInstalled = true
                    completion(true)
                }
            } else {
                DispatchQueue.main.async {
                    self.isInstalled = false
                    self.sessionStatus = .notInstalled
                    completion(false)
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isInstalled = false
                self.sessionStatus = .notInstalled
                completion(false)
            }
        }
    }
    
    /// Check if Claude CLI is authenticated
    func checkClaudeAuthentication(completion: @escaping (Bool) -> Void) {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["bash", "-c", "claude /doctor 2>&1 | grep -i 'auth'"]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), output.contains("authenticated") {
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                    completion(true)
                }
            } else {
                DispatchQueue.main.async {
                    self.isAuthenticated = false
                    completion(false)
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isAuthenticated = false
                completion(false)
            }
        }
    }
    
    /// Authenticate with Claude CLI using API key
    func authenticateClaudeCLI(apiKey: String? = nil, completion: @escaping (Bool) -> Void) {
        let task = Process()
        let pipe = Pipe()
        
        var key = apiKey
        
        if key == nil, let configKey = config?.apiKey {
            key = configKey
        }
        
        guard let validKey = key, !validKey.isEmpty else {
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["bash", "-c", "claude login --api-key=\"\(validKey)\""]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                    self.sessionStatus = .active
                    
                    // Update config if needed
                    if self.config == nil {
                        self.config = ClaudeConfig(apiKey: validKey, workspacePath: nil)
                    } else {
                        self.config?.apiKey = validKey
                    }
                    
                    completion(true)
                }
            } else {
                DispatchQueue.main.async {
                    self.isAuthenticated = false
                    self.sessionStatus = .notAuthenticated
                    completion(false)
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.sessionStatus = .error
                completion(false)
            }
        }
    }
    
    /// Initialize Claude CLI in a project
    func initializeClaudeCLI(projectPath: String? = nil, completion: @escaping (Bool) -> Void) {
        let task = Process()
        let pipe = Pipe()
        
        var path = projectPath
        
        if path == nil, let configPath = config?.workspacePath {
            path = configPath
        }
        
        var command = "claude init"
        if let validPath = path, !validPath.isEmpty {
            command = "cd \"\(validPath)\" && \(command)"
        }
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["bash", "-c", command]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                DispatchQueue.main.async {
                    self.sessionStatus = .active
                    
                    // Update config if needed
                    if let validPath = path, !validPath.isEmpty {
                        if self.config == nil {
                            self.config = ClaudeConfig(apiKey: "", workspacePath: validPath)
                        } else {
                            self.config?.workspacePath = validPath
                        }
                    }
                    
                    completion(true)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.sessionStatus = .error
                completion(false)
            }
        }
    }
    
    // MARK: - Command Routing
    
    /// Determine if a command should be routed to Claude based on content
    func shouldRouteToClaudeCLI(_ command: String) -> Bool {
        // List of prefixes that indicate a command should be routed to Claude
        let claudePrefixes = [
            "explain", "analyze", "summarize", "refactor", "optimize", 
            "document", "find bug", "fix bug", "add test", "implement", 
            "create function", "improve", "rewrite", "debug", "add comments"
        ]
        
        // Check if command starts with any of the Claude prefixes
        for prefix in claudePrefixes {
            if command.lowercased().hasPrefix(prefix.lowercased()) {
                return true
            }
        }
        
        // Check for code-related keywords
        let codeKeywords = ["function", "class", "method", "api", "interface", "code", "script"]
        if command.lowercased().contains("how to") {
            for keyword in codeKeywords {
                if command.lowercased().contains(keyword) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Execute a Claude command for code-related tasks
    func executeCodeCommand(_ command: String, options: String = "", completion: @escaping (String, Bool) -> Void) {
        guard isAuthenticated else {
            checkClaudeSetup()
            completion("Claude is not authenticated. Please check installation and authentication.", false)
            return
        }
        
        isProcessing = true
        
        // Send command to terminal through TerminalController
        terminalController.sendClaudeCommand(command, options: options)
        
        // Track command in history
        addToCommandHistory(command)
        
        // We don't get immediate output as it's handled by the terminal
        // The terminalController output subscription will process responses
        completion("Command sent to Claude", true)
    }
    
    /// Route a command to Claude if appropriate, otherwise to terminal
    func routeCommand(_ command: String, completion: @escaping (Bool) -> Void) {
        if shouldRouteToClaudeCLI(command) {
            // First make sure Claude is initialized if needed
            if !isClaudeInitialized {
                terminalController.initializeClaudeCLI()
                
                // Wait for initialization to complete before sending command
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.executeCodeCommand(command) { _, success in
                        completion(success)
                    }
                }
            } else {
                executeCodeCommand(command) { _, success in
                    completion(success)
                }
            }
        } else {
            // Not a Claude command, send to regular terminal
            terminalController.sendCommand(command)
            completion(true)
        }
    }
    
    /// Add a command to the history
    private func addToCommandHistory(_ command: String) {
        commandHistory.append(command)
        // Keep history at a reasonable size
        if commandHistory.count > 50 {
            commandHistory.removeFirst()
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
    
    /// Start a new Claude Code session
    func startClaudeSession(projectPath: String? = nil, apiKey: String? = nil, completion: @escaping (Bool) -> Void) {
        // First check if Claude is installed
        checkClaudeInstallation { [weak self] isInstalled in
            guard let self = self else { return }
            
            if isInstalled {
                // Check if Claude is authenticated
                self.checkClaudeAuthentication { isAuthenticated in
                    if !isAuthenticated {
                        // Try to authenticate
                        if let key = apiKey {
                            self.authenticateClaudeCLI(apiKey: key) { success in
                                if success {
                                    // Now initialize
                                    self.initializeClaudeCLI(projectPath: projectPath, completion: completion)
                                } else {
                                    completion(false)
                                }
                            }
                        } else {
                            completion(false)
                        }
                    } else {
                        // Already authenticated, just initialize
                        self.initializeClaudeCLI(projectPath: projectPath, completion: completion)
                    }
                }
            } else {
                // Claude is not installed
                self.sessionStatus = .notInstalled
                completion(false)
            }
        }
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
    
    /// End the current Claude session
    func endClaudeSession() {
        executeSlashCommand("clear")
        sessionStatus = .notAuthenticated
        isClaudeInitialized = false
    }
    
    /// Configure Claude CLI settings
    func configureClaudeSettings(settings: [String: String]) {
        var configCommand = "config"
        
        for (key, value) in settings {
            configCommand += " --\(key)=\(value)"
        }
        
        executeSlashCommand(configCommand)
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
                    sessionStatus = .active
                    
                    // Check if we should auto-respond to the prompt
                    processPromptAndAutoRespond(output)
                }
            }
        } catch {
            print("Error detecting Claude prompt: \(error)")
        }
    }
    
    // MARK: - Automated Decision Making
    
    /// Decision tree for responding to common Claude prompts
    func makeAutomatedDecision(for prompt: ClaudePrompt) -> DecisionOutcome {
        // Patterns that are safe to auto-approve
        let safeApprovalPatterns = [
            "Do you want to create a CLAUDE.md file",
            "Would you like me to commit these changes",
            "Do you want me to add comments to this code",
            "Start a new session",
            "Do you want to see more examples"
        ]
        
        // Patterns that should always be declined automatically
        let autoDeclinePatterns = [
            "delete file",
            "remove file",
            "clear all",
            "erase",
            "overwrite existing",
            "force push"
        ]
        
        // Patterns that require user input regardless of settings
        let requireUserPatterns = [
            "API key",
            "password",
            "credential",
            "authentication",
            "secret",
            "token"
        ]
        
        // First check for patterns that always require user input
        for pattern in requireUserPatterns {
            if prompt.prompt.lowercased().contains(pattern.lowercased()) {
                return .abort
            }
        }
        
        // Check for critical impact prompts
        if prompt.criticalImpact {
            return .abort // Always require user input for critical operations
        }
        
        // Check for safe approval patterns
        for pattern in safeApprovalPatterns {
            if prompt.prompt.lowercased().contains(pattern.lowercased()) {
                return .yes
            }
        }
        
        // Check for auto-decline patterns
        for pattern in autoDeclinePatterns {
            if prompt.prompt.lowercased().contains(pattern.lowercased()) {
                return .no
            }
        }
        
        // If we can detect specific selection options in the prompt
        if !prompt.possibleResponses.isEmpty {
            // If there are only 2 options and the first one seems affirmative
            if prompt.possibleResponses.count == 2 {
                let firstOption = prompt.possibleResponses[0].lowercased()
                if firstOption.contains("yes") || firstOption.contains("y") || 
                   firstOption.contains("ok") || firstOption.contains("sure") {
                    // For simple yes/no prompts that don't match any of our specific patterns,
                    // default to requiring user input
                    return .abort
                }
            }
            
            // For more complex selection prompts, always defer to user
            return .abort
        }
        
        // Default to requiring user input for anything not specifically handled
        return .abort
    }
    
    /// Auto respond to a Claude prompt based on context and prompt text
    func autoRespondToPrompt(_ prompt: String, context: String = "general") -> Bool {
        // First, parse the prompt to extract possible responses
        var possibleResponses: [String] = []
        
        // Look for patterns like [y/n], (1/2/3), etc.
        if let range = prompt.range(of: #"\[([^\]]+)\]"#, options: .regularExpression) {
            let options = prompt[range].dropFirst().dropLast().split(separator: "/")
            possibleResponses = options.map { String($0).trimmingCharacters(in: .whitespaces) }
        } else if let range = prompt.range(of: #"\(([^)]+)\)"#, options: .regularExpression) {
            let options = prompt[range].dropFirst().dropLast().split(separator: "/")
            possibleResponses = options.map { String($0).trimmingCharacters(in: .whitespaces) }
        }
        
        // Determine criticality
        let criticalImpact = prompt.lowercased().contains("delete") || 
                            prompt.lowercased().contains("overwrite") ||
                            prompt.lowercased().contains("remove") ||
                            prompt.lowercased().contains("replace") ||
                            prompt.lowercased().contains("permanent")
        
        // Create prompt structure
        let claudePrompt = ClaudePrompt(
            prompt: prompt,
            sourceContext: context,
            criticalImpact: criticalImpact,
            possibleResponses: possibleResponses
        )
        
        // Get the decision
        let decision = makeAutomatedDecision(for: claudePrompt)
        
        // Act on the decision
        switch decision {
        case .yes:
            terminalController.sendYes()
            print("Auto-responded 'yes' to prompt: \(prompt)")
            return true
        case .no:
            terminalController.sendNo()
            print("Auto-responded 'no' to prompt: \(prompt)")
            return true
        case .custom(let response):
            // Send the custom response followed by enter
            // This is more complex and would require sending individual keystrokes
            // For now, we'll just return false to have the user handle it
            print("Would send custom response: \(response)")
            return false
        case .abort:
            // Return false to indicate we didn't handle it automatically
            return false
        }
    }
    
    /// Process terminal output to detect prompts and potentially respond automatically
    func processPromptAndAutoRespond(_ terminalOutput: String) {
        // First check if this is a prompt that we should consider auto-responding to
        let promptPatterns = [
            "Do you want to",
            "Would you like to",
            "Proceed with",
            "Continue with",
            "Are you sure",
            "[y/n]",
            "(y/n)",
            "yes/no",
            "Please select:"
        ]
        
        var isPrompt = false
        var extractedPrompt = ""
        
        // Extract the prompt text
        for pattern in promptPatterns {
            if let range = terminalOutput.range(of: ".*\(pattern).*", options: .regularExpression) {
                extractedPrompt = String(terminalOutput[range])
                isPrompt = true
                break
            }
        }
        
        if isPrompt && !extractedPrompt.isEmpty {
            // Determine the context of the prompt
            var context = "general"
            
            if terminalOutput.contains("claude init") {
                context = "initialization"
            } else if terminalOutput.contains("claude commit") {
                context = "git_commit"
            } else if terminalOutput.contains("/review") {
                context = "code_review"
            } else if terminalOutput.contains("/doctor") {
                context = "diagnostics"
            }
            
            // Try to auto-respond
            let didAutoRespond = autoRespondToPrompt(extractedPrompt, context: context)
            
            if didAutoRespond {
                print("Auto-responded to prompt: \(extractedPrompt)")
            } else {
                print("Prompt requires user input: \(extractedPrompt)")
            }
        }
    }
    
    /// Check if a prompt should be auto-responded to based on user settings
    func shouldAutoRespond(to prompt: String, context: String) -> Bool {
        // This would typically check user preferences, but for now we'll implement a basic version
        // that only auto-responds to non-critical prompts
        
        // Critical contexts that should never be auto-responded to
        let criticalContexts = ["authentication", "deletion", "overwrite"]
        
        // Check if this is a critical context
        for criticalContext in criticalContexts {
            if context.contains(criticalContext) {
                return false
            }
        }
        
        // Critical terms in the prompt itself
        let criticalTerms = ["delete", "remove", "overwrite", "force", "password", "token", "api key"]
        
        // Check if the prompt contains critical terms
        for term in criticalTerms {
            if prompt.lowercased().contains(term) {
                return false
            }
        }
        
        // For this implementation, we'll auto-respond to simple yes/no questions that aren't critical
        return prompt.contains("[y/n]") || prompt.contains("(y/n)") || 
               prompt.contains("yes/no") || prompt.lowercased().contains("do you want to")
    }
}

/// Structured representation of a parsed Claude response
struct ParsedClaudeResponse {
    var mainText: String = ""
    var codeBlocks: [String] = []
    var containsFunctionCall: Bool = false
}

/// Represents the status of the Claude CLI session
enum ClaudeSessionStatus: String {
    case unknown
    case notInstalled = "Claude CLI is not installed"
    case notAuthenticated = "Claude CLI is not authenticated"
    case active = "Active"
    case error = "Error"
}

/// Configuration for Claude CLI
struct ClaudeConfig {
    var apiKey: String
    var workspacePath: String?
}

/// Decision outcome type for automated responses
enum DecisionOutcome {
    case yes            // Affirmative response
    case no             // Negative response
    case abort          // Don't respond automatically, defer to user
    case custom(String) // Custom response
}

/// Structure to represent a prompt that might be shown to the user
struct ClaudePrompt {
    let prompt: String          // The text of the prompt
    let sourceContext: String   // Context about where this prompt came from
    let criticalImpact: Bool    // Whether this prompt has critical impact
    var possibleResponses: [String] = [] // Possible response options
}
