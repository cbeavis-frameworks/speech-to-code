#!/usr/bin/swift

import Foundation

// Test script to verify Phase 1.2 Terminal Controller Enhancements for Claude Code CLI
print("Running Phase 1.2 Terminal Controller Enhancements Tests")
print("======================================================")

// Test 1: Check if TerminalController.swift has been enhanced with Claude Code support
let fileManager = FileManager.default
let terminalControllerPath = "./SpeechToCode/TerminalController.swift"

if fileManager.fileExists(atPath: terminalControllerPath) {
    print("✅ TerminalController.swift exists")
    
    do {
        let terminalControllerContent = try String(contentsOfFile: terminalControllerPath, encoding: .utf8)
        
        // Check for Claude Code CLI-specific command support
        if terminalControllerContent.contains("ClaudeCommand") || 
           terminalControllerContent.contains("sendClaudeCommand") {
            print("✅ TerminalController supports Claude Code CLI-specific commands")
        } else {
            print("❌ TerminalController does not support Claude Code CLI-specific commands")
        }
        
        // Check for Claude Code interactive prompt detection
        if terminalControllerContent.contains("claudeInteractivePatterns") || 
           terminalControllerContent.contains("detectClaudePrompt") {
            print("✅ TerminalController includes detection for Claude Code interactive prompts")
        } else {
            print("❌ TerminalController does not include detection for Claude Code interactive prompts")
        }
        
        // Check for Claude Code command history tracking
        if terminalControllerContent.contains("claudeCommandHistory") || 
           terminalControllerContent.contains("trackClaudeCommand") {
            print("✅ TerminalController implements Claude Code command history tracking")
        } else {
            print("❌ TerminalController does not implement Claude Code command history tracking")
        }
        
        // Check for specialized response parsing for Claude Code output
        if terminalControllerContent.contains("parseClaudeResponse") || 
           terminalControllerContent.contains("claudeOutputParser") {
            print("✅ TerminalController includes specialized response parsing for Claude Code output")
        } else {
            print("❌ TerminalController does not include specialized response parsing for Claude Code output")
        }
        
    } catch {
        print("❌ Failed to read TerminalController.swift: \(error)")
    }
} else {
    print("❌ TerminalController.swift does not exist")
}

// Test 2: Check if Claude Code CLI helper functions exist
let claudeHelperPath = "./SpeechToCode/ClaudeHelper.swift"

if fileManager.fileExists(atPath: claudeHelperPath) {
    print("✅ ClaudeHelper.swift exists")
    
    do {
        let claudeHelperContent = try String(contentsOfFile: claudeHelperPath, encoding: .utf8)
        
        // Check for Claude CLI initialization
        if claudeHelperContent.contains("initializeClaudeCLI") {
            print("✅ ClaudeHelper includes Claude CLI initialization")
        } else {
            print("❌ ClaudeHelper does not include Claude CLI initialization")
        }
        
        // Check for Claude prompt formatting
        if claudeHelperContent.contains("formatClaudePrompt") {
            print("✅ ClaudeHelper includes Claude prompt formatting")
        } else {
            print("❌ ClaudeHelper does not include Claude prompt formatting")
        }
        
        // Check for Claude response handling
        if claudeHelperContent.contains("handleClaudeResponse") {
            print("✅ ClaudeHelper includes Claude response handling")
        } else {
            print("❌ ClaudeHelper does not include Claude response handling")
        }
        
    } catch {
        print("❌ Failed to read ClaudeHelper.swift: \(error)")
    }
} else {
    print("❌ ClaudeHelper.swift does not exist")
}

// Test 3: Check if terminal_helper.sh has been updated with Claude CLI support
let terminalHelperPath = "./terminal_helper.sh"

if fileManager.fileExists(atPath: terminalHelperPath) {
    print("✅ terminal_helper.sh exists")
    
    do {
        let terminalHelperContent = try String(contentsOfFile: terminalHelperPath, encoding: .utf8)
        
        // Check for Claude CLI specific functions
        if terminalHelperContent.contains("claude_command") || 
           terminalHelperContent.contains("handle_claude") {
            print("✅ terminal_helper.sh includes Claude CLI specific functions")
        } else {
            print("❌ terminal_helper.sh does not include Claude CLI specific functions")
        }
        
        // Check for Claude prompt detection
        if terminalHelperContent.contains("detect_claude_prompt") {
            print("✅ terminal_helper.sh includes Claude prompt detection")
        } else {
            print("❌ terminal_helper.sh does not include Claude prompt detection")
        }
        
    } catch {
        print("❌ Failed to read terminal_helper.sh: \(error)")
    }
} else {
    print("❌ terminal_helper.sh does not exist")
}

// Test 4: Check if Claude CLI integration tests exist
let claudeTestsPath = "./SpeechToCode/Tests/ClaudeIntegrationTests.swift"

if fileManager.fileExists(atPath: claudeTestsPath) {
    print("✅ ClaudeIntegrationTests.swift exists")
    
    do {
        let claudeTestsContent = try String(contentsOfFile: claudeTestsPath, encoding: .utf8)
        
        // Check for basic Claude command test
        if claudeTestsContent.contains("testClaudeCommand") {
            print("✅ ClaudeIntegrationTests includes basic Claude command test")
        } else {
            print("❌ ClaudeIntegrationTests does not include basic Claude command test")
        }
        
        // Check for Claude interactive prompt test
        if claudeTestsContent.contains("testClaudeInteractivePrompt") {
            print("✅ ClaudeIntegrationTests includes Claude interactive prompt test")
        } else {
            print("❌ ClaudeIntegrationTests does not include Claude interactive prompt test")
        }
        
        // Check for Claude command history test
        if claudeTestsContent.contains("testClaudeCommandHistory") {
            print("✅ ClaudeIntegrationTests includes Claude command history test")
        } else {
            print("❌ ClaudeIntegrationTests does not include Claude command history test")
        }
        
        // Check for Claude response parsing test
        if claudeTestsContent.contains("testClaudeResponseParsing") {
            print("✅ ClaudeIntegrationTests includes Claude response parsing test")
        } else {
            print("❌ ClaudeIntegrationTests does not include Claude response parsing test")
        }
        
    } catch {
        print("❌ Failed to read ClaudeIntegrationTests.swift: \(error)")
    }
} else {
    print("❌ ClaudeIntegrationTests.swift does not exist")
}

print("\nPhase 1.2 Terminal Controller Enhancements Tests Complete")
