#!/usr/bin/swift

import Foundation

// Test script to verify Phase 1.3 AI Agent Models implementation
print("Running Phase 1.3 AI Agent Models Tests")
print("======================================")

// Test 1: Check if all required model files have been created
let fileManager = FileManager.default
let modelsDirectory = "./SpeechToCode/Models"

// Check if Models directory exists
if fileManager.fileExists(atPath: modelsDirectory) {
    print("✅ Models directory exists")
} else {
    print("❌ Models directory does not exist")
}

// Check for each model file
let requiredModelFiles = [
    "AgentMessage.swift",
    "RealtimeSession.swift",
    "ConversationAgent.swift",
    "PlanningAgent.swift"
]

for file in requiredModelFiles {
    let filePath = "\(modelsDirectory)/\(file)"
    
    if fileManager.fileExists(atPath: filePath) {
        print("✅ \(file) exists")
        
        do {
            let fileContent = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Test model-specific required components
            if file == "AgentMessage.swift" {
                if fileContent.contains("struct AgentMessage") && 
                   fileContent.contains("enum MessageType") {
                    print("  ✅ AgentMessage contains required components")
                } else {
                    print("  ❌ AgentMessage is missing required components")
                }
            } else if file == "RealtimeSession.swift" {
                if fileContent.contains("class RealtimeSession") && 
                   fileContent.contains("WebSocket") {
                    print("  ✅ RealtimeSession contains required components")
                } else {
                    print("  ❌ RealtimeSession is missing required components")
                }
            } else if file == "ConversationAgent.swift" {
                if fileContent.contains("class ConversationAgent") && 
                   fileContent.contains("AgentState") {
                    print("  ✅ ConversationAgent contains required components")
                } else {
                    print("  ❌ ConversationAgent is missing required components")
                }
            } else if file == "PlanningAgent.swift" {
                if fileContent.contains("class PlanningAgent") && 
                   fileContent.contains("PlanStorage") {
                    print("  ✅ PlanningAgent contains required components")
                } else {
                    print("  ❌ PlanningAgent is missing required components")
                }
            }
            
        } catch {
            print("❌ Failed to read \(file): \(error)")
        }
    } else {
        print("❌ \(file) does not exist")
    }
}

// Test 2: Check for agent message types
let agentMessagePath = "\(modelsDirectory)/AgentMessage.swift"
if fileManager.fileExists(atPath: agentMessagePath) {
    do {
        let agentMessageContent = try String(contentsOfFile: agentMessagePath, encoding: .utf8)
        
        // Check for message types
        let requiredMessageTypes = [
            "userInput", 
            "userOutput", 
            "conversationToPlanningAgent", 
            "planningToConversationAgent",
            "terminalCommand",
            "terminalResponse",
            "functionCall",
            "functionResult"
        ]
        
        var foundTypes = 0
        for type in requiredMessageTypes {
            if agentMessageContent.contains(type) {
                foundTypes += 1
            }
        }
        
        print("✅ Found \(foundTypes)/\(requiredMessageTypes.count) required message types")
        
    } catch {
        print("❌ Failed to read AgentMessage.swift: \(error)")
    }
}

// Test 3: Check for RealtimeSession connection methods
let realtimeSessionPath = "\(modelsDirectory)/RealtimeSession.swift"
if fileManager.fileExists(atPath: realtimeSessionPath) {
    do {
        let realtimeSessionContent = try String(contentsOfFile: realtimeSessionPath, encoding: .utf8)
        
        // Check for connection methods
        if realtimeSessionContent.contains("func connect") {
            print("✅ RealtimeSession includes connection method")
        } else {
            print("❌ RealtimeSession is missing connection method")
        }
        
        // Check for message sending
        if realtimeSessionContent.contains("func sendUserMessage") {
            print("✅ RealtimeSession includes message sending")
        } else {
            print("❌ RealtimeSession is missing message sending")
        }
        
        // Check for function calling
        if realtimeSessionContent.contains("func requestFunctionCall") {
            print("✅ RealtimeSession includes function calling")
        } else {
            print("❌ RealtimeSession is missing function calling")
        }
        
    } catch {
        print("❌ Failed to read RealtimeSession.swift: \(error)")
    }
}

// Test 4: Check for Agent communication
let conversationAgentPath = "\(modelsDirectory)/ConversationAgent.swift"
if fileManager.fileExists(atPath: conversationAgentPath) {
    do {
        let conversationAgentContent = try String(contentsOfFile: conversationAgentPath, encoding: .utf8)
        
        // Check for planning agent connection
        if conversationAgentContent.contains("connectToPlanningAgent") {
            print("✅ ConversationAgent includes planning agent connection")
        } else {
            print("❌ ConversationAgent is missing planning agent connection")
        }
        
        // Check for terminal controller connection
        if conversationAgentContent.contains("connectToTerminalController") {
            print("✅ ConversationAgent includes terminal controller connection")
        } else {
            print("❌ ConversationAgent is missing terminal controller connection")
        }
        
        // Check for message processing
        if conversationAgentContent.contains("processUserInput") {
            print("✅ ConversationAgent includes user input processing")
        } else {
            print("❌ ConversationAgent is missing user input processing")
        }
        
    } catch {
        print("❌ Failed to read ConversationAgent.swift: \(error)")
    }
}

// Test 5: Check for Planning Agent storage
let planningAgentPath = "\(modelsDirectory)/PlanningAgent.swift"
if fileManager.fileExists(atPath: planningAgentPath) {
    do {
        let planningAgentContent = try String(contentsOfFile: planningAgentPath, encoding: .utf8)
        
        // Check for plan storage
        if planningAgentContent.contains("protocol PlanStorage") {
            print("✅ PlanningAgent includes PlanStorage protocol")
        } else {
            print("❌ PlanningAgent is missing PlanStorage protocol")
        }
        
        // Check for file-based storage
        if planningAgentContent.contains("class FileBasedPlanStorage") {
            print("✅ PlanningAgent includes FileBasedPlanStorage implementation")
        } else {
            print("❌ PlanningAgent is missing FileBasedPlanStorage implementation")
        }
        
        // Check for plan item model
        if planningAgentContent.contains("struct PlanItem") {
            print("✅ PlanningAgent includes PlanItem struct")
        } else {
            print("❌ PlanningAgent is missing PlanItem struct")
        }
        
    } catch {
        print("❌ Failed to read PlanningAgent.swift: \(error)")
    }
}

print("\nPhase 1.3 AI Agent Models Tests Complete")
