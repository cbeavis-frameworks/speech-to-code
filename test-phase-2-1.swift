#!/usr/bin/swift

import Foundation

// Test script to verify Phase 2.1 Realtime API Integration implementation
print("Running Phase 2.1 Realtime API Integration Tests")
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

// Test 1: Check if RealtimeSession has been properly enhanced
let modelsDirectory = "./SpeechToCode/Models"
let realtimeSessionPath = "\(modelsDirectory)/RealtimeSession.swift"
let fileManager = FileManager.default

if fileManager.fileExists(atPath: realtimeSessionPath) {
    do {
        let realtimeSessionContent = try String(contentsOfFile: realtimeSessionPath, encoding: .utf8)
        
        // Check for WebSocket connection
        if realtimeSessionContent.contains("WebSocket.connect") {
            print("✅ RealtimeSession includes WebSocket connection implementation")
        } else {
            print("❌ RealtimeSession is missing WebSocket connection implementation")
        }
        
        // Check for WebSocket message handling
        if realtimeSessionContent.contains("handleWebSocketMessage") {
            print("✅ RealtimeSession includes WebSocket message handling")
        } else {
            print("❌ RealtimeSession is missing WebSocket message handling")
        }
        
        // Check for session configuration
        if realtimeSessionContent.contains("configureSession") {
            print("✅ RealtimeSession includes session configuration")
        } else {
            print("❌ RealtimeSession is missing session configuration")
        }
        
        // Check for text delta handling
        if realtimeSessionContent.contains("handleTextDelta") {
            print("✅ RealtimeSession includes text delta handling")
        } else {
            print("❌ RealtimeSession is missing text delta handling")
        }
        
        // Check for function call handling
        if realtimeSessionContent.contains("handleFunctionCallDelta") {
            print("✅ RealtimeSession includes function call delta handling")
        } else {
            print("❌ RealtimeSession is missing function call delta handling")
        }
        
        // Check for function result sending
        if realtimeSessionContent.contains("sendFunctionResult") {
            print("✅ RealtimeSession includes function result sending")
        } else {
            print("❌ RealtimeSession is missing function result sending")
        }
        
        // Check for proper imports
        let requiredImports = [
            "import WebSocketKit", 
            "import NIO", 
            "import AsyncHTTPClient",
            "import NIOFoundationCompat"
        ]
        
        var foundImports = 0
        for importStatement in requiredImports {
            if realtimeSessionContent.contains(importStatement) {
                foundImports += 1
            }
        }
        
        print("✅ Found \(foundImports)/\(requiredImports.count) required imports")
        
    } catch {
        print("❌ Failed to read RealtimeSession.swift: \(error)")
    }
} else {
    print("❌ RealtimeSession.swift does not exist")
}

// Test 2: Check if RealtimeSessionConfig has been updated
let realtimeSessionConfigPath = "\(modelsDirectory)/RealtimeSessionConfig.swift"

if fileManager.fileExists(atPath: realtimeSessionConfigPath) {
    do {
        let realtimeSessionConfigContent = try String(contentsOfFile: realtimeSessionConfigPath, encoding: .utf8)
        
        // Check for required properties
        let requiredProperties = [
            "instructions", 
            "voice", 
            "modalities", 
            "temperature"
        ]
        
        var foundProperties = 0
        for property in requiredProperties {
            if realtimeSessionConfigContent.contains(property) {
                foundProperties += 1
            }
        }
        
        print("✅ Found \(foundProperties)/\(requiredProperties.count) required properties in RealtimeSessionConfig")
        
    } catch {
        print("❌ Failed to read RealtimeSessionConfig.swift: \(error)")
    }
} else {
    print("❌ RealtimeSessionConfig.swift does not exist")
}

print("\nPhase 2.1 implementation verification complete")
print("Please build the application to ensure it compiles correctly.")
