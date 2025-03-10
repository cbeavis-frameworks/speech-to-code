#!/usr/bin/swift

import Foundation

// MARK: - Test Phase 4.3: Automated Decision Making

print("\n📱 SpeechToCode - Phase 4.3 Test Script: Automated Decision Making\n")

// Path to terminal helper script
let helperScriptPath = "/Users/chrisbeavis/Desktop/SpeechToCode/terminal_helper.sh"

// MARK: - Mock Classes

// Mock TerminalController to simulate terminal interactions
class MockTerminalController: ObservableObject {
    var terminalOutput: String = ""
    var isConnected: Bool = true
    var isInteractiveMode: Bool = false
    var isClaudeMode: Bool = false
    var lastTerminalContent: String = ""
    var keystrokesSent: [String] = []
    
    let helperScriptPath = "/Users/chrisbeavis/Desktop/SpeechToCode/terminal_helper.sh"
    
    func sendCommand(_ command: String) {
        print("  [Terminal] Sending command: \(command)")
        terminalOutput += "\n$ \(command)\nCommand output..."
    }
    
    func sendClaudeCommand(_ command: String, options: String = "") {
        print("  [Claude] Sending command: \(command)")
        terminalOutput += "\n> claude \"\(command)\"\nClaude processing..."
        isClaudeMode = true
    }
    
    func sendKeystroke(_ key: String) {
        print("  [Terminal] Sending keystroke: \(key)")
        keystrokesSent.append(key)
        terminalOutput += "\n[Keystroke: \(key)]"
    }
    
    func sendYes() {
        sendKeystroke("y")
    }
    
    func sendNo() {
        sendKeystroke("n")
    }
    
    func sendEnter() {
        sendKeystroke("enter")
    }
    
    // Method to simulate terminal output including prompts
    func simulateOutput(_ output: String) {
        terminalOutput += "\n\(output)"
        lastTerminalContent = terminalOutput
    }
}

// MARK: - Test Implementation of ClaudeHelper

class TestClaudeHelper {
    var isClaudeInitialized: Bool = false
    var lastResponse: String = ""
    var commandHistory: [String] = []
    var sessionStatus: ClaudeSessionStatus = .unknown
    var isAuthenticated: Bool = false
    var isProcessing: Bool = false
    var autoResponseLog: [(prompt: String, decision: DecisionOutcome)] = []
    
    private var terminalController: MockTerminalController
    
    init(terminalController: MockTerminalController) {
        self.terminalController = terminalController
    }
    
    // MARK: - Automated Decision Making Implementation
    
    enum DecisionOutcome: Equatable {
        case yes            // Affirmative response
        case no             // Negative response
        case abort          // Don't respond automatically, defer to user
        case custom(String) // Custom response
        
        static func == (lhs: DecisionOutcome, rhs: DecisionOutcome) -> Bool {
            switch (lhs, rhs) {
            case (.yes, .yes): return true
            case (.no, .no): return true
            case (.abort, .abort): return true
            case (.custom(let lhsValue), .custom(let rhsValue)): return lhsValue == rhsValue
            default: return false
            }
        }
    }
    
    struct ClaudePrompt {
        let prompt: String          // The text of the prompt
        let sourceContext: String   // Context about where this prompt came from
        let criticalImpact: Bool    // Whether this prompt has critical impact
        var possibleResponses: [String] = [] // Possible response options
    }
    
    enum ClaudeSessionStatus: String {
        case unknown
        case notInstalled = "Claude CLI is not installed"
        case notAuthenticated = "Claude CLI is not authenticated"
        case active = "Active"
        case error = "Error"
    }
    
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
            "clear all settings",
            "erase"
        ]
        
        // Patterns that require user input regardless of settings
        let requireUserPatterns = [
            "api key",
            "password",
            "credential",
            "authentication",
            "secret",
            "token",
            "delete file",
            "remove file", 
            "overwrite existing",
            "force push"
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
        
        // Log the decision for testing
        autoResponseLog.append((prompt: prompt, decision: decision))
        
        // Act on the decision
        switch decision {
        case .yes:
            terminalController.sendYes()
            print("  Auto-responded 'yes' to prompt: \(prompt)")
            return true
        case .no:
            terminalController.sendNo()
            print("  Auto-responded 'no' to prompt: \(prompt)")
            return true
        case .custom(let response):
            print("  Would send custom response: \(response)")
            return false
        case .abort:
            print("  Requiring user input for prompt: \(prompt)")
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
            "Please select:",
            "Enter your API key",
            "provide your password",
            "Authentication token",
            "Delete file",
            "Remove file",
            "Force push"
        ]
        
        var isPrompt = false
        var extractedPrompt = ""
        
        // Extract the prompt text from the latest output
        let lines = terminalOutput.components(separatedBy: .newlines)
        if let lastLine = lines.last, !lastLine.isEmpty {
            for pattern in promptPatterns {
                if lastLine.contains(pattern) {
                    extractedPrompt = lastLine
                    isPrompt = true
                    break
                }
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
                print("  Auto-responded to prompt: \(extractedPrompt)")
            } else {
                print("  Prompt requires user input: \(extractedPrompt)")
            }
        }
    }
}

// MARK: - Test Scenarios

// Testing utility to validate the automated decision-making
func testAutomatedDecisionMaking() {
    print("\n--- Testing Automated Decision Making Logic ---\n")
    
    let mockTerminal = MockTerminalController()
    let claudeHelper = TestClaudeHelper(terminalController: mockTerminal)
    
    // Test Case 1: Safe prompts that should be auto-approved
    print("Test Case 1: Safe prompts that should be auto-approved")
    let safePrompts = [
        "Do you want to create a CLAUDE.md file? [y/n]",
        "Would you like me to commit these changes? (y/n)",
        "Do you want me to add comments to this code? [y/n]",
        "Do you want to see more examples? [y/n]"
    ]
    
    mockTerminal.terminalOutput = ""
    claudeHelper.autoResponseLog = []
    
    for prompt in safePrompts {
        mockTerminal.simulateOutput(prompt)
        claudeHelper.processPromptAndAutoRespond(mockTerminal.terminalOutput)
    }
    
    // Check if all safe prompts were auto-approved with "yes"
    var safeYesCount = 0
    for i in 0..<claudeHelper.autoResponseLog.count {
        if i < safePrompts.count && claudeHelper.autoResponseLog[i].decision == .yes {
            safeYesCount += 1
        }
    }
    
    let safePromptsAutoApproved = safeYesCount == safePrompts.count
    
    if safePromptsAutoApproved {
        print("✅ All safe prompts were correctly auto-approved")
    } else {
        print("❌ Not all safe prompts were auto-approved as expected")
        print("   Expected: \(safePrompts.count), Got: \(safeYesCount)")
    }
    
    // Test Case 2: Prompts that should be auto-declined
    print("\nTest Case 2: Prompts that should be auto-declined")
    let autoDeclinePrompts = [
        "Clear all settings? [y/n]"
    ]
    
    mockTerminal.terminalOutput = ""
    claudeHelper.autoResponseLog = []
    
    for prompt in autoDeclinePrompts {
        mockTerminal.simulateOutput(prompt)
        claudeHelper.processPromptAndAutoRespond(mockTerminal.terminalOutput)
    }
    
    // Check if dangerous prompts were auto-declined with "no"
    var dangerousNoCount = 0
    for i in 0..<claudeHelper.autoResponseLog.count {
        if i < autoDeclinePrompts.count && claudeHelper.autoResponseLog[i].decision == .no {
            dangerousNoCount += 1
        }
    }
    
    let dangerousPromptsAutoDeclined = dangerousNoCount == autoDeclinePrompts.count
    
    if dangerousPromptsAutoDeclined {
        print("✅ All auto-decline prompts were correctly declined")
    } else {
        print("❌ Not all auto-decline prompts were actually declined as expected")
        print("   Expected: \(autoDeclinePrompts.count), Got: \(dangerousNoCount)")
        for i in 0..<claudeHelper.autoResponseLog.count {
            print("   Prompt: \(claudeHelper.autoResponseLog[i].prompt), Decision: \(claudeHelper.autoResponseLog[i].decision)")
        }
    }
    
    // Test Case 3: Critical prompts that require user input
    print("\nTest Case 3: Critical prompts that require user input")
    let criticalPrompts = [
        "Delete file server.js? [y/n]",
        "Remove file config.json? [y/n]",
        "Force push to remote repository? [y/n]",
        "Enter your API key:",
        "Please provide your password:",
        "Authentication token required:",
        "Overwrite existing file? [y/n]"
    ]
    
    mockTerminal.terminalOutput = ""
    claudeHelper.autoResponseLog = []
    
    for prompt in criticalPrompts {
        mockTerminal.simulateOutput(prompt)
        claudeHelper.processPromptAndAutoRespond(mockTerminal.terminalOutput)
    }
    
    // Check if critical prompts required user input
    var criticalAbortCount = 0
    for i in 0..<claudeHelper.autoResponseLog.count {
        if i < criticalPrompts.count && claudeHelper.autoResponseLog[i].decision == .abort {
            criticalAbortCount += 1
        }
    }
    
    let criticalPromptsRequireInput = criticalAbortCount == criticalPrompts.count
    
    if criticalPromptsRequireInput {
        print("✅ All critical prompts correctly required user input")
    } else {
        print("❌ Not all critical prompts required user input as expected")
        print("   Expected: \(criticalPrompts.count), Got: \(criticalAbortCount)")
        for i in 0..<claudeHelper.autoResponseLog.count {
            print("   Prompt: \(claudeHelper.autoResponseLog[i].prompt), Decision: \(claudeHelper.autoResponseLog[i].decision)")
        }
    }
    
    // Print summary of keystroke interactions
    print("\nKeystroke interactions summary:")
    print("- 'Yes' responses: \(mockTerminal.keystrokesSent.filter { $0 == "y" }.count)")
    print("- 'No' responses: \(mockTerminal.keystrokesSent.filter { $0 == "n" }.count)")
    print("- Total automated responses: \(mockTerminal.keystrokesSent.count)")
    
    // Overall test result
    if safePromptsAutoApproved && dangerousPromptsAutoDeclined && criticalPromptsRequireInput {
        print("\n✅ Phase 4.3 Automated Decision Making Test PASSED")
    } else {
        print("\n❌ Phase 4.3 Automated Decision Making Test FAILED")
    }
}

// Test actual integration with helper script
func testHelperScriptIntegration() {
    print("\n--- Testing Integration with Terminal Helper Script ---\n")
    
    // Test detect_claude_prompt function from helper script
    let task = Process()
    let pipe = Pipe()
    
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = [helperScriptPath, "detect_claude_prompt"]
    task.standardOutput = pipe
    
    do {
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            print("Claude prompt detection test result: \(result)")
            
            if result == "claude_prompt_detected" || result == "no_claude_prompt" {
                print("✅ Helper script integration test PASSED")
            } else {
                print("❌ Helper script integration test FAILED: Unexpected response")
            }
        } else {
            print("❌ Helper script integration test FAILED: No output")
        }
    } catch {
        print("❌ Helper script integration test FAILED: \(error)")
    }
}

// Run all tests
print("Running Phase 4.3 Automated Decision Making tests...\n")
testAutomatedDecisionMaking()
testHelperScriptIntegration()
print("\nCompleted test for Phase 4.3: Automated Decision Making")
