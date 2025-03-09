#!/usr/bin/swift

import Foundation

// Test script to verify Phase 2.2 Speech Processing implementation (REVISED)
print("Running Phase 2.2 Speech Processing Tests (REVISED)")
print("===============================================")

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

// Check OpenAI API key
if let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !openAIKey.isEmpty {
    print("✅ OpenAI API key is set")
} else {
    print("❌ OpenAI API key is not set")
}

// Test 1: Check VoiceProcessor implementation using Speech framework
let modelsDirectory = "./SpeechToCode/Models"
let voiceProcessorPath = "\(modelsDirectory)/VoiceProcessor.swift"
let fileManager = FileManager.default

if fileManager.fileExists(atPath: voiceProcessorPath) {
    do {
        let voiceProcessorContent = try String(contentsOfFile: voiceProcessorPath, encoding: .utf8)
        
        // Check for Speech framework import
        if voiceProcessorContent.contains("import Speech") {
            print("✅ VoiceProcessor imports Speech framework")
        } else {
            print("❌ VoiceProcessor is missing Speech framework import")
        }
        
        // Check for SFSpeechRecognizer usage
        if voiceProcessorContent.contains("SFSpeechRecognizer") {
            print("✅ VoiceProcessor uses SFSpeechRecognizer")
        } else {
            print("❌ VoiceProcessor is missing SFSpeechRecognizer implementation")
        }
        
        // Check for recognition request
        if voiceProcessorContent.contains("SFSpeechAudioBufferRecognitionRequest") {
            print("✅ VoiceProcessor includes recognition request setup")
        } else {
            print("❌ VoiceProcessor is missing recognition request setup")
        }
        
        // Check for voice activation detection
        if voiceProcessorContent.contains("detectVoiceActivity") || voiceProcessorContent.contains("isVoiceActive") {
            print("✅ VoiceProcessor includes voice activation detection")
        } else {
            print("❌ VoiceProcessor is missing voice activation detection")
        }
        
        // Check for speech synthesis
        if voiceProcessorContent.contains("AVSpeechSynthesizer") || voiceProcessorContent.contains("playSpeech") {
            print("✅ VoiceProcessor includes speech synthesis")
        } else {
            print("❌ VoiceProcessor is missing speech synthesis")
        }
        
        // Check for proper class declaration
        if voiceProcessorContent.contains("class VoiceProcessor: NSObject, ObservableObject") {
            print("✅ VoiceProcessor is properly declared as ObservableObject")
        } else {
            print("❌ VoiceProcessor is not properly declared as ObservableObject")
        }
        
    } catch {
        print("❌ Failed to read VoiceProcessor.swift: \(error)")
    }
} else {
    print("❌ VoiceProcessor.swift does not exist")
}

// Test 2: Check if RealtimeSession has been enhanced with speech processing capabilities
let realtimeSessionPath = "\(modelsDirectory)/RealtimeSession.swift"

if fileManager.fileExists(atPath: realtimeSessionPath) {
    do {
        let realtimeSessionContent = try String(contentsOfFile: realtimeSessionPath, encoding: .utf8)
        
        // Check for VoiceProcessor integration
        if realtimeSessionContent.contains("voiceProcessor") {
            print("✅ RealtimeSession includes VoiceProcessor integration")
        } else {
            print("❌ RealtimeSession is missing VoiceProcessor integration")
        }
        
        // Check for speech processing methods
        if realtimeSessionContent.contains("startListening") {
            print("✅ RealtimeSession includes voice input handling")
        } else {
            print("❌ RealtimeSession is missing voice input handling")
        }
        
        // Check for transcription handling
        if realtimeSessionContent.contains("onTranscription") {
            print("✅ RealtimeSession includes transcription handling")
        } else {
            print("❌ RealtimeSession is missing transcription handling")
        }
        
        // Verify no audio streaming
        if !realtimeSessionContent.contains("sendAudioData") {
            print("✅ RealtimeSession properly uses text-based API interaction (no audio streaming)")
        } else {
            print("❌ RealtimeSession still contains audio streaming code that should be removed")
        }
        
    } catch {
        print("❌ Failed to read RealtimeSession.swift: \(error)")
    }
} else {
    print("❌ RealtimeSession.swift does not exist")
}

// Test 3: Check if ConversationAgent has been updated with speech processing support
let conversationAgentPath = "\(modelsDirectory)/ConversationAgent.swift"

if fileManager.fileExists(atPath: conversationAgentPath) {
    do {
        let conversationAgentContent = try String(contentsOfFile: conversationAgentPath, encoding: .utf8)
        
        // Check for speech processing states
        if conversationAgentContent.contains("listeningForVoice") {
            print("✅ ConversationAgent includes voice processing states")
        } else {
            print("❌ ConversationAgent is missing voice processing states")
        }
        
        // Check for voice control methods
        if conversationAgentContent.contains("startListening") && conversationAgentContent.contains("stopListening") {
            print("✅ ConversationAgent includes voice control methods")
        } else {
            print("❌ ConversationAgent is missing voice control methods")
        }
        
        // Check for transcription handling
        if conversationAgentContent.contains("currentTranscription") {
            print("✅ ConversationAgent includes transcription handling")
        } else {
            print("❌ ConversationAgent is missing transcription handling")
        }
        
        // Check for voice commands processing
        if conversationAgentContent.contains("processVoiceCommand") {
            print("✅ ConversationAgent includes voice commands processing")
        } else {
            print("❌ ConversationAgent is missing voice commands processing")
        }
        
    } catch {
        print("❌ Failed to read ConversationAgent.swift: \(error)")
    }
} else {
    print("❌ ConversationAgent.swift does not exist")
}

// Test 4: Check if AgentMessage has been updated with voice message types
let agentMessagePath = "\(modelsDirectory)/AgentMessage.swift"

if fileManager.fileExists(atPath: agentMessagePath) {
    do {
        let agentMessageContent = try String(contentsOfFile: agentMessagePath, encoding: .utf8)
        
        // Check for voice message types
        if agentMessageContent.contains("case voiceInput") && agentMessageContent.contains("case voiceOutput") {
            print("✅ AgentMessage includes voice message types")
        } else {
            print("❌ AgentMessage is missing voice message types")
        }
        
        // Check for voice message factory methods
        if agentMessageContent.contains("static func voiceInput") && agentMessageContent.contains("static func voiceOutput") {
            print("✅ AgentMessage includes voice message factory methods")
        } else {
            print("❌ AgentMessage is missing voice message factory methods")
        }
        
    } catch {
        print("❌ Failed to read AgentMessage.swift: \(error)")
    }
} else {
    print("❌ AgentMessage.swift does not exist")
}

print("\nPhase 2.2 (REVISED) implementation verification complete")
print("Please build the application to ensure it compiles correctly.")
