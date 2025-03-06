import Foundation

/// Configuration for the SpeechToCode app
struct Config {
    /// OpenAI API configuration
    struct OpenAI {
        /// The OpenAI API key
        static var apiKey: String {
            ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        }
        
        /// The base URL for the OpenAI API
        static let apiBaseURL = "https://api.openai.com/v1"
        
        /// The model ID for GPT-4o
        static let gpt4oModel = "gpt-4o"
        
        /// The model ID for GPT-4o Mini
        static let gpt4oMiniModel = "gpt-4o-mini"
        
        /// The model ID for GPT-4o Realtime
        static let gpt4oRealtimeModel = "gpt-4o-2024-05-13"
        
        /// The model ID for GPT-4o Mini Realtime
        static let gpt4oMiniRealtimeModel = "gpt-4o-mini-2024-07-18"
    }
    
    /// Anthropic API configuration
    struct Anthropic {
        /// The Anthropic API key
        static var apiKey: String {
            ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        }
        
        /// The base URL for the Anthropic API
        static let apiBaseURL = "https://api.anthropic.com/v1"
        
        /// The model ID for Claude 3 Opus
        static let claude3OpusModel = "claude-3-opus-20240229"
        
        /// The model ID for Claude 3 Sonnet
        static let claude3SonnetModel = "claude-3-sonnet-20240229"
        
        /// The model ID for Claude 3 Haiku
        static let claude3HaikuModel = "claude-3-haiku-20240307"
    }
    
    /// App configuration
    struct App {
        /// The directory for storing app data
        static let storageDirectory: URL = {
            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appStorageURL = appSupportURL.appendingPathComponent("SpeechToCode", isDirectory: true)
            
            if !fileManager.fileExists(atPath: appStorageURL.path) {
                try? fileManager.createDirectory(at: appStorageURL, withIntermediateDirectories: true)
            }
            
            return appStorageURL
        }()
        
        /// Whether to use the mini model for conversation
        static let useMiniModelForConversation = true
        
        /// Whether to use the mini model for planning
        static let useMiniModelForPlanning = true
    }
    
    /// Load environment variables from .env file
    static func loadEnvironmentVariables() {
        let fileManager = FileManager.default
        let envFilePath = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(".env").path
        
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
            } catch {
                print("Error loading .env file: \(error)")
            }
        }
    }
}
