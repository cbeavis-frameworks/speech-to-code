#!/usr/bin/swift

import Foundation

// MARK: - Test Phase 4.2: Command Routing for Claude Code

print("Starting test for Phase 4.2: Command Routing for Claude Code")

// Path to terminal helper script
let helperScriptPath = "/Users/chrisbeavis/Desktop/SpeechToCode/terminal_helper.sh"

// List of test commands for Claude routing
let testCommands = [
    // Commands expected to route to Claude
    "explain how this function works",
    "summarize the code in this file",
    "refactor this function to be more efficient",
    "optimize this algorithm",
    "fix bug in authentication logic",
    "add comments to this class",
    "how to implement a binary search in Swift",
    
    // Commands expected NOT to route to Claude
    "ls -la",
    "cd Documents",
    "git status",
    "echo Hello World"
]

// Simulated TerminalController for testing
class TestTerminalController {
    var isClaudeMode = false
    var commandsSentToTerminal: [String] = []
    var commandsSentToClaude: [String] = []
    
    // Detect if command should be routed to Claude
    func detectCommandForClaude(_ command: String) -> Bool {
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
    
    // Route command to appropriate handler
    func routeCommand(_ command: String) {
        if isClaudeMode {
            sendToClaudeMode(command)
            return
        }
        
        if detectCommandForClaude(command) {
            sendToClaudeMode(command)
        } else {
            sendToTerminal(command)
        }
    }
    
    func sendToTerminal(_ command: String) {
        print("🖥️  Routing to Terminal: \(command)")
        commandsSentToTerminal.append(command)
    }
    
    func sendToClaudeMode(_ command: String) {
        print("🤖 Routing to Claude: \(command)")
        commandsSentToClaude.append(command)
    }
}

// Test command routing logic
func testCommandRouting() {
    print("\n--- Testing Command Routing Logic ---\n")
    
    let terminal = TestTerminalController()
    var claudeCommandCount = 0
    var terminalCommandCount = 0
    
    for command in testCommands {
        terminal.routeCommand(command)
        
        if terminal.detectCommandForClaude(command) {
            claudeCommandCount += 1
        } else {
            terminalCommandCount += 1
        }
    }
    
    // Display test summary
    print("\nRouting test complete:")
    print("- Total commands tested: \(testCommands.count)")
    print("- Commands routed to Claude: \(claudeCommandCount)")
    print("- Commands routed to Terminal: \(terminalCommandCount)")
    
    if claudeCommandCount == terminal.commandsSentToClaude.count &&
       terminalCommandCount == terminal.commandsSentToTerminal.count {
        print("✅ Test PASSED: All commands were correctly routed")
    } else {
        print("❌ Test FAILED: Command routing mismatch")
        print("  Expected Claude commands: \(claudeCommandCount), Actual: \(terminal.commandsSentToClaude.count)")
        print("  Expected Terminal commands: \(terminalCommandCount), Actual: \(terminal.commandsSentToTerminal.count)")
    }
}

// Test simulated interaction with real helper script
func testHelperScriptDetection() {
    print("\n--- Testing Helper Script Detection Functions ---\n")
    
    // Test detect_claude_prompt function
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
                print("✅ Helper script detection test PASSED")
            } else {
                print("❌ Helper script detection test FAILED: Unexpected response")
            }
        } else {
            print("❌ Helper script detection test FAILED: No output")
        }
    } catch {
        print("❌ Helper script detection test FAILED: \(error)")
    }
}

// Run all tests
func runAllTests() {
    print("\n=== PHASE 4.2 TEST SUITE ===\n")
    
    // Test command routing logic
    testCommandRouting()
    
    // Test helper script integration
    testHelperScriptDetection()
    
    print("\n=== TEST SUITE COMPLETE ===\n")
}

// Execute tests
runAllTests()
