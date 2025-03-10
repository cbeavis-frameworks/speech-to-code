#!/usr/bin/swift

import Foundation

// MARK: - Test Phase 4.3: Automated Decision Making

print("Starting test for Phase 4.3: Automated Decision Making")

// Path to terminal helper script
let helperScriptPath = "/Users/chrisbeavis/Desktop/SpeechToCode/terminal_helper.sh"

// Mock implementation of the decision outcome enum
enum DecisionOutcome {
    case yes            // Affirmative response
    case no             // Negative response
    case abort          // Don't respond automatically, defer to user
    case custom(String) // Custom response
}

// Mock implementation of the prompt structure
struct ClaudePrompt {
    let prompt: String          // The text of the prompt
    let sourceContext: String   // Context about where this prompt came from
    let criticalImpact: Bool    // Whether this prompt has critical impact
    var possibleResponses: [String] = [] // Possible response options
}

// Test prompts for automated decision making
let testPrompts = [
    // Safe prompts that should be auto-approved
    "Do you want to create a CLAUDE.md file? [y/n]",
    "Would you like me to commit these changes? (y/n)",
    "Do you want me to add comments to this code? [y/n]",
    "Do you want to see more examples? [y/n]",
    
    // Prompts that should be auto-declined
    "Delete file server.js? [y/n]",
    "Remove file config.json? [y/n]",
    "Clear all settings? [y/n]",
    "Overwrite existing file? [y/n]",
    
    // Critical prompts that require user input
    "Enter your API key:",
    "Please provide your password:",
    "Authentication token required:",
    "Force push to remote repository? [y/n]"
]

// Simulated automated decision-making functions
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
    
    // Default to requiring user input for anything not specifically handled
    return .abort
}

// Helper function to extract possible responses from a prompt
func extractPossibleResponses(from prompt: String) -> [String] {
    var possibleResponses: [String] = []
    
    // Look for patterns like [y/n], (1/2/3), etc.
    if let range = prompt.range(of: #"\[([^\]]+)\]"#, options: .regularExpression) {
        let options = prompt[range].dropFirst().dropLast().split(separator: "/")
        possibleResponses = options.map { String($0).trimmingCharacters(in: .whitespaces) }
    } else if let range = prompt.range(of: #"\(([^)]+)\)"#, options: .regularExpression) {
        let options = prompt[range].dropFirst().dropLast().split(separator: "/")
        possibleResponses = options.map { String($0).trimmingCharacters(in: .whitespaces) }
    }
    
    return possibleResponses
}

// Function to determine if a prompt has critical impact
func hasCriticalImpact(_ prompt: String) -> Bool {
    let criticalTerms = ["delete", "remove", "overwrite", "replace", "permanent", "force"]
    return criticalTerms.contains { prompt.lowercased().contains($0) }
}

// Test the automated decision making logic
func runDecisionTests() {
    print("\n--- Testing Automated Decision Making ---\n")
    
    for (index, promptText) in testPrompts.enumerated() {
        print("Test Prompt \(index + 1): \"\(promptText)\"")
        
        // Determine context (simple example)
        let context = promptText.contains("commit") ? "git_commit" : 
                     promptText.contains("file") ? "file_operation" : "general"
        
        // Extract possible responses
        let possibleResponses = extractPossibleResponses(from: promptText)
        print("  Possible Responses: \(possibleResponses)")
        
        // Check for critical impact
        let criticalImpact = hasCriticalImpact(promptText)
        print("  Critical Impact: \(criticalImpact)")
        
        // Create prompt structure
        let claudePrompt = ClaudePrompt(
            prompt: promptText,
            sourceContext: context,
            criticalImpact: criticalImpact,
            possibleResponses: possibleResponses
        )
        
        // Get the decision
        let decision = makeAutomatedDecision(for: claudePrompt)
        
        // Print the result
        switch decision {
        case .yes:
            print("  Decision: Auto-respond with YES")
        case .no:
            print("  Decision: Auto-respond with NO")
        case .custom(let response):
            print("  Decision: Auto-respond with custom text: \(response)")
        case .abort:
            print("  Decision: ABORT - Require user input")
        }
        
        print("")
    }
}

// Run the tests
runDecisionTests()

print("\nCompleted test for Phase 4.3: Automated Decision Making")
