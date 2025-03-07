import Foundation

/// A structured message format for communication between agents
struct AgentMessage: Codable, Identifiable {
    /// Unique identifier for the message
    var id: UUID = UUID()
    
    /// Type of message
    enum MessageType: String, Codable {
        /// Message from the user
        case userInput
        /// Message to the user
        case userOutput
        /// Message from the Conversation Agent to the Planning Agent
        case conversationToPlanningAgent
        /// Message from the Planning Agent to the Conversation Agent
        case planningToConversationAgent
        /// Message for terminal command execution
        case terminalCommand
        /// Response from a terminal command
        case terminalResponse
        /// Function call message
        case functionCall
        /// Function result message
        case functionResult
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
    
    /// Create a user input message
    /// - Parameter content: User input text
    /// - Returns: An AgentMessage with the user input
    static func userInput(_ content: String) -> AgentMessage {
        return AgentMessage(
            messageType: .userInput,
            sender: "User",
            recipient: "ConversationAgent",
            content: content
        )
    }
    
    /// Create a user output message
    /// - Parameter content: Text to display to the user
    /// - Returns: An AgentMessage with text for the user
    static func userOutput(_ content: String) -> AgentMessage {
        return AgentMessage(
            messageType: .userOutput,
            sender: "ConversationAgent",
            recipient: "User",
            content: content
        )
    }
    
    /// Create a terminal command message
    /// - Parameter command: The command to execute
    /// - Returns: An AgentMessage with the terminal command
    static func terminalCommand(_ command: String) -> AgentMessage {
        return AgentMessage(
            messageType: .terminalCommand,
            sender: "ConversationAgent",
            recipient: "TerminalController",
            content: command
        )
    }
    
    /// Create a terminal response message
    /// - Parameter response: The response from the terminal
    /// - Returns: An AgentMessage with the terminal response
    static func terminalResponse(_ response: String) -> AgentMessage {
        return AgentMessage(
            messageType: .terminalResponse,
            sender: "TerminalController",
            recipient: "ConversationAgent",
            content: response
        )
    }
}
