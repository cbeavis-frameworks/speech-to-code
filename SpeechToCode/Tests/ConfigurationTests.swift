import XCTest
import Foundation
import SwiftUI

/// Tests to verify that the Phase 1.1 Project Configuration requirements are met
class ConfigurationTests: XCTestCase {
    
    /// Test that the OpenAI API client dependencies are properly configured
    func testDependenciesAvailable() {
        // Check if the required modules can be imported
        // Note: This is a compile-time check. If the dependencies are missing,
        // this test file won't compile.
        
        // The following imports should be available if dependencies are configured correctly
        #if canImport(WebSocketKit)
            print("WebSocketKit is available")
        #else
            XCTFail("WebSocketKit dependency is not available")
        #endif
        
        #if canImport(NIO)
            print("NIO is available")
        #else
            XCTFail("NIO dependency is not available")
        #endif
        
        #if canImport(AsyncHTTPClient)
            print("AsyncHTTPClient is available")
        #else
            XCTFail("AsyncHTTPClient dependency is not available")
        #endif
        
        // This test passes if it compiles and runs
        XCTAssertTrue(true, "Dependencies are properly configured")
    }
    
    /// Test that the Config struct is properly initialized
    func testConfigStructExists() {
        // Verify that the Config struct exists and can be accessed
        let openAIBaseURL = Config.OpenAI.apiBaseURL
        XCTAssertEqual(openAIBaseURL, "https://api.openai.com/v1", "OpenAI base URL is correctly configured")
        
        let anthropicBaseURL = Config.Anthropic.apiBaseURL
        XCTAssertEqual(anthropicBaseURL, "https://api.anthropic.com/v1", "Anthropic base URL is correctly configured")
        
        // Verify that the storage directory is created
        let storageDirectory = Config.App.storageDirectory
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: storageDirectory.path), "Storage directory exists")
    }
    
    /// Test that environment variables can be loaded
    func testEnvironmentVariablesLoading() {
        // Create a temporary .env file for testing
        let tempEnvPath = NSTemporaryDirectory() + "test.env"
        let envContent = """
        TEST_API_KEY=test_key_12345
        TEST_OTHER_VALUE=some_value
        """
        
        do {
            try envContent.write(toFile: tempEnvPath, atomically: true, encoding: .utf8)
            
            // Load the environment variables
            loadTestEnvironmentVariables(fromPath: tempEnvPath)
            
            // Check if the variables were loaded
            let apiKey = ProcessInfo.processInfo.environment["TEST_API_KEY"]
            XCTAssertEqual(apiKey, "test_key_12345", "API key was loaded from .env file")
            
            let otherValue = ProcessInfo.processInfo.environment["TEST_OTHER_VALUE"]
            XCTAssertEqual(otherValue, "some_value", "Other value was loaded from .env file")
            
            // Clean up
            try FileManager.default.removeItem(atPath: tempEnvPath)
        } catch {
            XCTFail("Failed to create or clean up test .env file: \(error)")
        }
    }
    
    /// Test that the entitlements are properly configured
    func testEntitlementsConfiguration() {
        // This is a manual verification since entitlements can't be directly tested at runtime
        // We'll check the bundle's Info.plist for the required usage descriptions
        
        let bundle = Bundle.main
        
        // Check for microphone usage description
        let microphoneUsageDescription = bundle.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String
        XCTAssertNotNil(microphoneUsageDescription, "Microphone usage description is configured in Info.plist")
        
        // Check for speech recognition usage description
        let speechRecognitionUsageDescription = bundle.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") as? String
        XCTAssertNotNil(speechRecognitionUsageDescription, "Speech recognition usage description is configured in Info.plist")
        
        // Check for Apple Events usage description
        let appleEventsUsageDescription = bundle.object(forInfoDictionaryKey: "NSAppleEventsUsageDescription") as? String
        XCTAssertNotNil(appleEventsUsageDescription, "Apple Events usage description is configured in Info.plist")
    }
    
    /// Helper function to load environment variables from a specific path
    private func loadTestEnvironmentVariables(fromPath path: String) {
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: path) {
            do {
                let envFileContent = try String(contentsOfFile: path, encoding: .utf8)
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
            } catch {
                XCTFail("Error loading test .env file: \(error)")
            }
        }
    }
}
