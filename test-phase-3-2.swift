#!/usr/bin/swift

import Foundation

// Test script to verify Phase 3.2 Plan Management implementation
print("Running Phase 3.2 Plan Management Tests")
print("=======================================")

// Load environment variables from .env file (similar to Config.loadEnvironmentVariables)
func loadEnvironmentVariables() {
    let fileManager = FileManager.default
    let envFilePath = "./.env"
    
    if fileManager.fileExists(atPath: envFilePath) {
        do {
            let envFileContent = try String(contentsOfFile: envFilePath, encoding: .utf8)
            let envVars = envFileContent.components(separatedBy: .newlines)
            
            for envVar in envVars {
                let trimmedVar = envVar.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip comments and empty lines
                if trimmedVar.isEmpty || trimmedVar.hasPrefix("#") {
                    continue
                }
                
                let components = trimmedVar.components(separatedBy: "=")
                if components.count >= 2 {
                    let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = components[1...].joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Remove quotes if present
                    var processedValue = value
                    if (processedValue.hasPrefix("\"") && processedValue.hasSuffix("\"")) ||
                       (processedValue.hasPrefix("'") && processedValue.hasSuffix("'")) {
                        processedValue = String(processedValue.dropFirst().dropLast())
                    }
                    
                    setenv(key, processedValue, 1)
                }
            }
            print("✅ Successfully loaded environment variables from .env")
        } catch {
            print("❌ Error loading .env file: \(error)")
        }
    } else {
        print("❌ .env file not found at path: \(envFilePath)")
        print("Please copy .env.template to .env and fill in your API keys")
    }
}

// Load environment variables
loadEnvironmentVariables()

// Check OpenAI API key (still needed for other parts of the app)
if let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !openAIKey.isEmpty {
    print("✅ OpenAI API key is set")
} else {
    print("❌ OpenAI API key is not set")
}

// Test 1: Check PlanningAgent.swift for Phase 3.2 implementations
let modelsDirectory = "./SpeechToCode/Models"
let planningAgentPath = "\(modelsDirectory)/PlanningAgent.swift"
let fileManager = FileManager.default

if fileManager.fileExists(atPath: planningAgentPath) {
    do {
        let planningAgentContent = try String(contentsOfFile: planningAgentPath, encoding: .utf8)
        
        // Check for plan creation functionality
        if planningAgentContent.contains("func createNewPlan") {
            print("✅ PlanningAgent has plan creation functionality")
        } else {
            print("❌ PlanningAgent is missing plan creation functionality")
        }
        
        // Check for plan versioning
        if planningAgentContent.contains("struct PlanVersion") &&
           planningAgentContent.contains("func saveCurrentPlanAsVersion") &&
           planningAgentContent.contains("func loadPlanVersion") &&
           planningAgentContent.contains("func deletePlanVersion") {
            print("✅ PlanningAgent includes plan versioning functionality")
        } else {
            print("❌ PlanningAgent is missing plan versioning functionality")
        }
        
        // Check for plan item history tracking
        if planningAgentContent.contains("struct HistoryEntry") &&
           planningAgentContent.contains("var historyEntries") &&
           planningAgentContent.contains("func getPlanItemHistory") {
            print("✅ PlanningAgent includes history tracking for plan items")
        } else {
            print("❌ PlanningAgent is missing history tracking for plan items")
        }
        
        // Check for advanced reporting features
        if planningAgentContent.contains("func generatePlanSummary") &&
           planningAgentContent.contains("func generatePriorityBasedReport") &&
           planningAgentContent.contains("func generateStatusBasedReport") {
            print("✅ PlanningAgent includes advanced reporting features")
        } else {
            print("❌ PlanningAgent is missing advanced reporting features")
        }
        
        // Check for agent communication enhancements
        if planningAgentContent.contains("func processAgentMessage") &&
           planningAgentContent.contains("func handlePlanQuery") &&
           planningAgentContent.contains("func handlePlanUpdateRequest") {
            print("✅ PlanningAgent includes agent communication functionality")
        } else {
            print("❌ PlanningAgent is missing agent communication functionality")
        }
        
        // Check for task dependency handling
        if planningAgentContent.contains("func addDependency") &&
           planningAgentContent.contains("func removeDependency") {
            print("✅ PlanningAgent includes task dependency handling")
        } else {
            print("❌ PlanningAgent is missing task dependency handling")
        }
        
        // Check for data initialization
        if planningAgentContent.contains("func initializeWithTestData") {
            print("✅ PlanningAgent includes test data initialization for development")
        } else {
            print("❌ PlanningAgent is missing test data initialization")
        }
        
        // Check for history entry comments
        if planningAgentContent.contains("func addCommentToPlanItem") {
            print("✅ PlanningAgent includes comment functionality for history entries")
        } else {
            print("❌ PlanningAgent is missing comment functionality for history entries")
        }
        
    } catch {
        print("❌ Failed to read PlanningAgent.swift: \(error)")
    }
} else {
    print("❌ PlanningAgent.swift does not exist")
}

// Test 2: Check for AgentMessage extensions for Plan Management functionality
let agentMessagePath = "\(modelsDirectory)/AgentMessage.swift"

if fileManager.fileExists(atPath: agentMessagePath) {
    do {
        let agentMessageContent = try String(contentsOfFile: agentMessagePath, encoding: .utf8)
        
        // Check for plan-related message types
        if agentMessageContent.contains("requestPlanUpdate") &&
           agentMessageContent.contains("planUpdateConfirmation") &&
           agentMessageContent.contains("requestPlanQuery") &&
           agentMessageContent.contains("planQueryResult") &&
           agentMessageContent.contains("requestPlanSummary") &&
           agentMessageContent.contains("planSummaryResult") {
            print("✅ AgentMessage includes plan management message types")
        } else {
            print("⚠️ AgentMessage may not include all required plan management message types")
            
            // Check which ones are missing
            if !agentMessageContent.contains("requestPlanUpdate") {
                print("  - Missing: requestPlanUpdate message type")
            }
            if !agentMessageContent.contains("planUpdateConfirmation") {
                print("  - Missing: planUpdateConfirmation message type")
            }
            if !agentMessageContent.contains("requestPlanQuery") {
                print("  - Missing: requestPlanQuery message type")
            }
            if !agentMessageContent.contains("planQueryResult") {
                print("  - Missing: planQueryResult message type")
            }
            if !agentMessageContent.contains("requestPlanSummary") {
                print("  - Missing: requestPlanSummary message type")
            }
            if !agentMessageContent.contains("planSummaryResult") {
                print("  - Missing: planSummaryResult message type")
            }
        }
        
    } catch {
        print("❌ Failed to read AgentMessage.swift: \(error)")
    }
} else {
    print("❌ AgentMessage.swift does not exist")
}

// Function to try to execute the test plan
func testPlanManagement() {
    print("\n## Manual Testing Plan Management Functionality ##")
    print("This section would typically be performed by a human tester, but")
    print("we'll simulate some basic operations to check implementation.\n")
    
    print("To fully test plan management, you would:")
    print("1. Create a new plan with tasks")
    print("2. Update task statuses and observe history tracking")
    print("3. Add comments to tasks")
    print("4. Save plan versions and restore them")
    print("5. Generate plan reports and summaries")
    print("6. Test agent communication for plan management\n")
    
    print("This test script only verifies the presence of the required functionality.")
    print("An interactive test would be needed to fully validate the implementation.")
}

testPlanManagement()

print("\nPhase 3.2 implementation verification complete")
print("Please build the application to ensure it compiles correctly.")
