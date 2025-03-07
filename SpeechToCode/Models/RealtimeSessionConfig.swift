import Foundation

/// Configuration for the OpenAI Realtime API session
struct RealtimeSessionConfig {
    /// The instructions for the agent
    let instructions: String
    
    /// The voice to use for text-to-speech
    let voice: String
    
    /// The modalities to enable (text, audio, etc.)
    let modalities: [String]
    
    /// The temperature for the model (0.0-1.0)
    let temperature: Float
    
    /// Default configuration
    static let `default` = RealtimeSessionConfig(
        instructions: "You are a helpful coding assistant.",
        voice: "alloy",
        modalities: ["text", "audio"],
        temperature: 0.7
    )
}
