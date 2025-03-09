import Foundation

/// A structured message format for communication between agents
struct AgentMessage: Codable, Identifiable {
    /// Unique identifier for the message
    var id: UUID = UUID()
    
    /// Type of message
    enum MessageType: String, Codable {
        /// Message from the user
        case userInput = "user_input"
        /// Message to the user
        case assistantOutput = "assistant_output"
        /// Message for terminal command execution
        case terminalCommand = "terminal_command"
        /// Response from a terminal command
        case terminalOutput = "terminal_output"
        /// Voice input from the user
        case voiceInput = "voice_input"
        /// Voice output to the user
        case voiceOutput = "voice_output"
        /// System message
        case systemMessage = "system_message"
        /// Planning request message
        case planningRequest = "planning_request"
        /// Planning response message
        case planningResponse = "planning_response"
        /// Error message
        case error = "error"
    }
    
    /// The type of this message
    let messageType: MessageType
    
    /// The sender of this message
    let sender: String
    
    /// The recipient of this message
    let recipient: String
    
    /// The content of the message
    let content: String
    
    /// Additional metadata for the message
    let metadata: [String: String]
    
    /// Timestamp of when the message was created
    let timestamp: Date
    
    /// Creates a new agent message
    /// - Parameters:
    ///   - messageType: The type of message
    ///   - sender: The sender identifier
    ///   - recipient: The recipient identifier
    ///   - content: The content of the message
    ///   - metadata: Optional metadata for the message
    init(messageType: MessageType, sender: String, recipient: String, content: String, metadata: [String: String] = [:]) {
        self.messageType = messageType
        self.sender = sender
        self.recipient = recipient
        self.content = content
        self.metadata = metadata
        self.timestamp = Date()
    }
    
    // MARK: - Factory Methods

    /// Create a user input message
    /// - Parameters:
    ///   - content: The user input content
    ///   - recipient: The recipient agent
    /// - Returns: An AgentMessage
    static func userInput(content: String, recipient: String = "ConversationAgent") -> AgentMessage {
        return AgentMessage(messageType: .userInput, sender: "User", recipient: recipient, content: content)
    }
    
    /// Create a voice input message
    /// - Parameters:
    ///   - transcription: The transcribed voice content
    ///   - recipient: The recipient agent
    /// - Returns: An AgentMessage
    static func voiceInput(transcription: String, recipient: String = "ConversationAgent") -> AgentMessage {
        return AgentMessage(messageType: .voiceInput, sender: "User", recipient: recipient, content: transcription)
    }
    
    /// Create a voice output message
    /// - Parameters:
    ///   - content: The content to be spoken
    ///   - sender: The sender agent
    /// - Returns: An AgentMessage
    static func voiceOutput(content: String, sender: String = "ConversationAgent") -> AgentMessage {
        return AgentMessage(messageType: .voiceOutput, sender: sender, recipient: "User", content: content)
    }
}
