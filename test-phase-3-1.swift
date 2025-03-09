#!/usr/bin/swift

import Foundation

// Test script to verify Phase 3.1 Plan Storage implementation
print("Running Phase 3.1 Plan Storage Tests")
print("====================================")

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

// Test 1: Check PlanStorage implementation
let modelsDirectory = "./SpeechToCode/Models"
let planStoragePath = "\(modelsDirectory)/PlanStorage.swift"
let fileManager = FileManager.default

if fileManager.fileExists(atPath: planStoragePath) {
    do {
        let planStorageContent = try String(contentsOfFile: planStoragePath, encoding: .utf8)
        
        // Check for PlanStorageProtocol
        if planStorageContent.contains("protocol PlanStorageProtocol") {
            print("✅ PlanStorage contains PlanStorageProtocol definition")
        } else {
            print("❌ PlanStorage is missing PlanStorageProtocol definition")
        }
        
        // Check for required protocol methods
        if planStorageContent.contains("func savePlan") &&
           planStorageContent.contains("func loadPlan") &&
           planStorageContent.contains("func saveProjectContext") &&
           planStorageContent.contains("func loadProjectContext") {
            print("✅ PlanStorage protocol defines basic CRUD operations")
        } else {
            print("❌ PlanStorage protocol is missing required CRUD methods")
        }
        
        // Check for backup functionality
        if planStorageContent.contains("func createBackup") &&
           planStorageContent.contains("func restoreFromBackup") &&
           planStorageContent.contains("func listBackups") &&
           planStorageContent.contains("func deleteBackup") {
            print("✅ PlanStorage includes backup and recovery functionality")
        } else {
            print("❌ PlanStorage is missing backup and recovery functionality")
        }
        
        // Check for PlanBackupInfo structure
        if planStorageContent.contains("struct PlanBackupInfo") {
            print("✅ PlanStorage includes PlanBackupInfo structure")
        } else {
            print("❌ PlanStorage is missing PlanBackupInfo structure")
        }
        
        // Check for FilePlanStorage implementation
        if planStorageContent.contains("class FilePlanStorage") {
            print("✅ PlanStorage includes FilePlanStorage implementation")
        } else {
            print("❌ PlanStorage is missing FilePlanStorage implementation")
        }
        
        // Check for error handling
        if planStorageContent.contains("enum PlanStorageError") {
            print("✅ PlanStorage includes error handling")
        } else {
            print("❌ PlanStorage is missing error handling")
        }
        
    } catch {
        print("❌ Failed to read PlanStorage.swift: \(error)")
    }
} else {
    print("❌ PlanStorage.swift does not exist")
}

// Test 2: Check PlanningAgent enhancements
let planningAgentPath = "\(modelsDirectory)/PlanningAgent.swift"

if fileManager.fileExists(atPath: planningAgentPath) {
    do {
        let planningAgentContent = try String(contentsOfFile: planningAgentPath, encoding: .utf8)
        
        // Check for enhanced PlanItem structure
        if planningAgentContent.contains("var priority: Priority") &&
           planningAgentContent.contains("var tags: [String]") &&
           planningAgentContent.contains("var dependencies: [UUID]") {
            print("✅ PlanningAgent has enhanced PlanItem with priority, tags, and dependencies")
        } else {
            print("❌ PlanningAgent is missing enhanced PlanItem fields")
        }
        
        // Check for PlanItem helper methods
        if planningAgentContent.contains("func updateStatus") &&
           planningAgentContent.contains("func addDependency") &&
           planningAgentContent.contains("func removeDependency") {
            print("✅ PlanningAgent has PlanItem helper methods")
        } else {
            print("❌ PlanningAgent is missing PlanItem helper methods")
        }
        
        // Check for backup integration
        if planningAgentContent.contains("func createBackup") &&
           planningAgentContent.contains("func restoreFromBackup") &&
           planningAgentContent.contains("func refreshBackupsList") &&
           planningAgentContent.contains("func deleteBackup") {
            print("✅ PlanningAgent includes backup and recovery methods")
        } else {
            print("❌ PlanningAgent is missing backup and recovery methods")
        }
        
        // Check for PlanStorageProtocol usage
        if planningAgentContent.contains("private let storage: PlanStorageProtocol") &&
           planningAgentContent.contains("self.storage = FilePlanStorage") {
            print("✅ PlanningAgent uses PlanStorageProtocol correctly")
        } else {
            print("❌ PlanningAgent is not using PlanStorageProtocol correctly")
        }
        
        // Check for enhanced formatting
        if planningAgentContent.contains("formatPlanItem") {
            print("✅ PlanningAgent includes improved plan formatting")
        } else {
            print("❌ PlanningAgent is missing improved plan formatting")
        }
        
        // Check for user input processing
        if planningAgentContent.contains("extractTitle") &&
           planningAgentContent.contains("extractDescription") {
            print("✅ PlanningAgent includes enhanced user input processing")
        } else {
            print("❌ PlanningAgent is missing enhanced user input processing")
        }
        
    } catch {
        print("❌ Failed to read PlanningAgent.swift: \(error)")
    }
} else {
    print("❌ PlanningAgent.swift does not exist")
}

print("\nPhase 3.1 implementation verification complete")
print("Please build the application to ensure it compiles correctly.")
