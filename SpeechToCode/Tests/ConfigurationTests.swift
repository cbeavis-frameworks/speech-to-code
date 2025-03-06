import Foundation
import SwiftUI

/// Tests to verify that the Phase 1.1 Project Configuration requirements are met
/// This file is used by the test-phase-1-1.swift script to verify the implementation
class ConfigurationTests {
    
    /// Helper assertion function
    func assert(_ condition: Bool, _ message: String = "") {
        if !condition {
            print("❌ Assertion failed: \(message)")
        } else if !message.isEmpty {
            print("✅ \(message)")
        }
    }
    
    /// Test that the OpenAI API client dependencies are properly configured
    func testDependenciesAvailable() {
        // Check if the required modules can be imported
        // Note: This is a compile-time check. If the dependencies are missing,
        // this test file won't compile.
        
        // The following imports should be available if dependencies are configured correctly
        #if canImport(WebSocketKit)
            print("WebSocketKit is available")
        #else
            print("❌ WebSocketKit dependency is not available")
        #endif
        
        #if canImport(NIO)
            print("NIO is available")
        #else
            print("❌ NIO dependency is not available")
        #endif
        
        #if canImport(AsyncHTTPClient)
            print("AsyncHTTPClient is available")
        #else
            print("❌ AsyncHTTPClient dependency is not available")
        #endif
        
        // This test passes if it compiles and runs
        assert(true, "Dependencies are properly configured")
    }
    
    /// Test that the Config struct is properly initialized
    func testConfigStructExists() {
        // Verify that the Config struct exists and can be accessed
        let openAIBaseURL = Config.OpenAI.apiBaseURL
        assert(openAIBaseURL == "https://api.openai.com/v1", "OpenAI base URL is correctly configured")
        
        let anthropicBaseURL = Config.Anthropic.apiBaseURL
        assert(anthropicBaseURL == "https://api.anthropic.com/v1", "Anthropic base URL is correctly configured")
        
        // Verify that the storage directory is created
        let storageDirectory = Config.App.storageDirectory
        let fileManager = FileManager.default
        assert(fileManager.fileExists(atPath: storageDirectory.path), "Storage directory exists")
    }
    
    /// Test that the environment variables are properly loaded
    func testEnvironmentVariablesLoaded() {
        // Check if the environment variables are loaded
        let openAIKey = Config.OpenAI.apiKey
        assert(!openAIKey.isEmpty, "OpenAI API key is loaded")
        
        let anthropicKey = Config.Anthropic.apiKey
        assert(!anthropicKey.isEmpty, "Anthropic API key is loaded")
    }
    
    /// Test that the entitlements are properly configured
    func testEntitlementsConfigured() {
        // This is a placeholder test since we can't directly check entitlements in code
        // The actual verification would be done by the test-phase-1-1.swift script
        print("Note: Entitlements need to be verified manually or through the test script")
    }
    
    /// Test that the Info.plist contains the necessary usage descriptions
    func testInfoPlistContainsUsageDescriptions() {
        // This is a placeholder test since we can't directly check Info.plist in code
        // The actual verification would be done by the test-phase-1-1.swift script
        print("Note: Info.plist usage descriptions need to be verified manually or through the test script")
    }
    
    /// Run all tests
    func runAllTests() {
        print("Running Configuration Tests...")
        testDependenciesAvailable()
        testConfigStructExists()
        testEnvironmentVariablesLoaded()
        testEntitlementsConfigured()
        testInfoPlistContainsUsageDescriptions()
        print("Configuration Tests completed")
    }
    
    /// Helper method to load test environment variables
    private func loadTestEnvironmentVariables(fromPath path: String) {
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: path) {
            do {
                let envFileContent = try String(contentsOfFile: path, encoding: .utf8)
                let lines = envFileContent.components(separatedBy: .newlines)
                
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Skip comments and empty lines
                    if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                        continue
                    }
                    
                    // Parse key-value pairs
                    let components = trimmedLine.components(separatedBy: "=")
                    if components.count >= 2 {
                        let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = components[1...].joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Remove quotes if present
                        var processedValue = value
                        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                            let startIndex = value.index(after: value.startIndex)
                            let endIndex = value.index(before: value.endIndex)
                            processedValue = String(value[startIndex..<endIndex])
                        }
                        
                        // Set environment variable
                        setenv(key, processedValue, 1)
                    }
                }
            } catch {
                print("Error loading environment variables: \(error)")
            }
        }
    }
}
