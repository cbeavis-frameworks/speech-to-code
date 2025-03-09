import Foundation
import Combine

/// Helper class for interacting with Claude Code CLI
class ClaudeHelper: ObservableObject {
    @Published var isClaudeInitialized: Bool = false
    @Published var lastResponse: String = ""
    @Published var commandHistory: [String] = []
    @Published var sessionStatus: ClaudeSessionStatus = .notInitialized
    @Published var isAuthenticated: Bool = false
    @Published var isProcessing: Bool = false
    
    private var terminalController: TerminalController
    private var cancellables = Set<AnyCancellable>()
    private let config: ClaudeConfig
    
    init(terminalController: TerminalController) {
        self.terminalController = terminalController
        self.config = ClaudeConfig()
        
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
                self.sessionStatus = .notInitialized
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
        
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "which claude"]
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let status = task.terminationStatus
            completion(status == 0)
        } catch {
            print("Error checking Claude installation: \(error)")
            completion(false)
        }
    }
    
    /// Check if Claude CLI is authenticated
    func checkClaudeAuthentication(completion: @escaping (Bool) -> Void) {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [terminalController.helperScriptPath, "handle_claude", "check_auth"]
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                completion(output.contains("authenticated"))
            } else {
                completion(false)
            }
        } catch {
            print("Error checking Claude authentication: \(error)")
            completion(false)
        }
    }
    
    /// Initialize Claude CLI in the current directory
    func initializeClaudeCLI(projectPath: String? = nil, completion: @escaping (Bool) -> Void) {
        sessionStatus = .initializing
        isProcessing = true
        
        let path = projectPath ?? FileManager.default.currentDirectoryPath
        
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [terminalController.helperScriptPath, "handle_claude", "init", path]
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if task.terminationStatus == 0 {
                isClaudeInitialized = true
                sessionStatus = .initialized
                print("Claude CLI initialized successfully in \(path)")
                completion(true)
            } else {
                print("Error initializing Claude CLI: \(output)")
                sessionStatus = .initializationFailed
                completion(false)
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            sessionStatus = .initializationFailed
            completion(false)
        }
        
        isProcessing = false
    }
    
    /// Authenticate with Claude CLI using the API key
    func authenticateClaudeCLI(apiKey: String? = nil, completion: @escaping (Bool) -> Void) {
        isProcessing = true
        
        // Use provided API key or get from Config
        let key = apiKey ?? Config.Anthropic.apiKey
        
        guard !key.isEmpty else {
            print("Cannot authenticate: API key is empty")
            completion(false)
            isProcessing = false
            return
        }
        
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [terminalController.helperScriptPath, "handle_claude", "login", key]
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if task.terminationStatus == 0 && !output.contains("error") {
                isAuthenticated = true
                print("Claude CLI authenticated successfully")
                completion(true)
            } else {
                print("Error authenticating Claude CLI: \(output)")
                completion(false)
            }
        } catch {
            print("Error during Claude authentication: \(error)")
            completion(false)
        }
        
        isProcessing = false
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
    func startClaudeSession(projectPath: String? = nil, completion: @escaping (Bool) -> Void) {
        // First check if Claude is installed
        checkClaudeInstallation { [weak self] isInstalled in
            guard let self = self else { return }
            
            if !isInstalled {
                print("Claude CLI is not installed")
                self.sessionStatus = .notInstalled
                completion(false)
                return
            }
            
            // Then check if authenticated
            self.checkClaudeAuthentication { isAuthenticated in
                if !isAuthenticated {
                    print("Claude CLI is not authenticated")
                    self.sessionStatus = .authenticationRequired
                    completion(false)
                    return
                }
                
                // Initialize Claude CLI
                self.initializeClaudeCLI(projectPath: projectPath) { success in
                    if success {
                        // Run a basic command to ensure the session is active
                        self.executeSlashCommand("clear")
                        self.sessionStatus = .active
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
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
        sessionStatus = .notInitialized
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

/// Represents the status of the Claude CLI session
enum ClaudeSessionStatus: String {
    case notInstalled = "Claude CLI is not installed"
    case notInitialized = "Not initialized"
    case initializing = "Initializing..."
    case initialized = "Initialized"
    case initializationFailed = "Initialization failed"
    case authenticationRequired = "Authentication required"
    case active = "Active"
    case error = "Error"
}

/// Configuration for Claude CLI
struct ClaudeConfig {
    var model: String = "claude-3-haiku-20240307" // Default model
    var temperature: Double = 0.7
    var maxTokens: Int = 4000
    
    /// Get config as command line arguments string
    var asCommandLineArgs: String {
        return "--model=\(model) --temperature=\(temperature) --max-tokens=\(maxTokens)"
    }
}
