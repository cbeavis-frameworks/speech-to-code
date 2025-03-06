#!/usr/bin/swift

import Foundation

// Simple test script to verify Phase 1.1 configuration
print("Running Phase 1.1 Configuration Tests")
print("=====================================")

// Test 1: Check if Package.swift exists
let fileManager = FileManager.default
let packagePath = "./Package.swift"
if fileManager.fileExists(atPath: packagePath) {
    print("✅ Package.swift exists")
    
    do {
        let packageContent = try String(contentsOfFile: packagePath, encoding: .utf8)
        if packageContent.contains("websocket-kit") && 
           packageContent.contains("swift-nio") && 
           packageContent.contains("async-http-client") {
            print("✅ Package.swift contains required dependencies")
        } else {
            print("❌ Package.swift is missing some required dependencies")
        }
    } catch {
        print("❌ Failed to read Package.swift: \(error)")
    }
} else {
    print("❌ Package.swift does not exist")
}

// Test 2: Check if Config.swift exists
let configPath = "./SpeechToCode/Config.swift"
if fileManager.fileExists(atPath: configPath) {
    print("✅ Config.swift exists")
    
    do {
        let configContent = try String(contentsOfFile: configPath, encoding: .utf8)
        if configContent.contains("struct OpenAI") && 
           configContent.contains("struct Anthropic") && 
           configContent.contains("loadEnvironmentVariables") {
            print("✅ Config.swift contains required components")
        } else {
            print("❌ Config.swift is missing some required components")
        }
    } catch {
        print("❌ Failed to read Config.swift: \(error)")
    }
} else {
    print("❌ Config.swift does not exist")
}

// Test 3: Check if .env.template exists
let envTemplatePath = "./.env.template"
if fileManager.fileExists(atPath: envTemplatePath) {
    print("✅ .env.template exists")
    
    do {
        let envTemplateContent = try String(contentsOfFile: envTemplatePath, encoding: .utf8)
        if envTemplateContent.contains("OPENAI_API_KEY") && 
           envTemplateContent.contains("ANTHROPIC_API_KEY") {
            print("✅ .env.template contains required API key placeholders")
        } else {
            print("❌ .env.template is missing some required API key placeholders")
        }
    } catch {
        print("❌ Failed to read .env.template: \(error)")
    }
} else {
    print("❌ .env.template does not exist")
}

// Test 4: Check if entitlements are properly configured
let entitlementsPath = "./SpeechToCode/SpeechToCode.entitlements"
if fileManager.fileExists(atPath: entitlementsPath) {
    print("✅ SpeechToCode.entitlements exists")
    
    do {
        let entitlementsContent = try String(contentsOfFile: entitlementsPath, encoding: .utf8)
        var missingEntitlements: [String] = []
        
        if !entitlementsContent.contains("com.apple.security.automation.apple-events") {
            missingEntitlements.append("com.apple.security.automation.apple-events")
        }
        
        if !entitlementsContent.contains("com.apple.security.network.client") {
            missingEntitlements.append("com.apple.security.network.client")
        }
        
        if !entitlementsContent.contains("com.apple.security.files.user-selected.read-write") {
            missingEntitlements.append("com.apple.security.files.user-selected.read-write")
        }
        
        if !entitlementsContent.contains("com.apple.security.device.audio-input") {
            missingEntitlements.append("com.apple.security.device.audio-input")
        }
        
        if missingEntitlements.isEmpty {
            print("✅ SpeechToCode.entitlements contains all required permissions")
        } else {
            print("❌ SpeechToCode.entitlements is missing the following permissions: \(missingEntitlements.joined(separator: ", "))")
        }
    } catch {
        print("❌ Failed to read SpeechToCode.entitlements: \(error)")
    }
} else {
    print("❌ SpeechToCode.entitlements does not exist")
}

// Test 5: Check if Info.plist is properly configured
let infoPlistPath = "./SpeechToCode/Info.plist"
if fileManager.fileExists(atPath: infoPlistPath) {
    print("✅ Info.plist exists")
    
    do {
        let infoPlistContent = try String(contentsOfFile: infoPlistPath, encoding: .utf8)
        var missingDescriptions: [String] = []
        
        if !infoPlistContent.contains("NSMicrophoneUsageDescription") {
            missingDescriptions.append("NSMicrophoneUsageDescription")
        }
        
        if !infoPlistContent.contains("NSSpeechRecognitionUsageDescription") {
            missingDescriptions.append("NSSpeechRecognitionUsageDescription")
        }
        
        if !infoPlistContent.contains("NSAppleEventsUsageDescription") {
            missingDescriptions.append("NSAppleEventsUsageDescription")
        }
        
        if missingDescriptions.isEmpty {
            print("✅ Info.plist contains all required usage descriptions")
        } else {
            print("❌ Info.plist is missing the following usage descriptions: \(missingDescriptions.joined(separator: ", "))")
        }
    } catch {
        print("❌ Failed to read Info.plist: \(error)")
    }
} else {
    print("❌ Info.plist does not exist")
}

// Test 6: Check if .gitignore is properly configured
let gitignorePath = "./.gitignore"
if fileManager.fileExists(atPath: gitignorePath) {
    print("✅ .gitignore exists")
    
    do {
        let gitignoreContent = try String(contentsOfFile: gitignorePath, encoding: .utf8)
        if gitignoreContent.contains(".env") {
            print("✅ .gitignore excludes .env file")
        } else {
            print("❌ .gitignore does not exclude .env file")
        }
    } catch {
        print("❌ Failed to read .gitignore: \(error)")
    }
} else {
    print("❌ .gitignore does not exist")
}

print("\nPhase 1.1 Configuration Tests Complete")
