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
        /// Request to update the plan
        case requestPlanUpdate = "request_plan_update"
        /// Confirmation of plan update
        case planUpdateConfirmation = "plan_update_confirmation"
        /// Request to query the plan
        case requestPlanQuery = "request_plan_query"
        /// Result of a plan query
        case planQueryResult = "plan_query_result"
        /// Request for a plan summary
        case requestPlanSummary = "request_plan_summary"
        /// Result of a plan summary request
        case planSummaryResult = "plan_summary_result"
        /// Request for project context
        case requestProjectContext = "request_project_context"
        /// Result of a project context request
        case projectContextResult = "project_context_result"
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
    
    // MARK: - Plan Management Functions
    
    /// Create a request to update the plan
    /// - Parameter content: The plan update details
    /// - Returns: An AgentMessage
    static func requestPlanUpdate(content: String, sender: String = "ConversationAgent") -> AgentMessage {
        return AgentMessage(messageType: .requestPlanUpdate, sender: sender, recipient: "PlanningAgent", content: content)
    }
    
    /// Create a plan update confirmation
    /// - Parameter message: The confirmation message
    /// - Returns: An AgentMessage
    static func planUpdateConfirmation(message: String, sender: String = "PlanningAgent") -> AgentMessage {
        return AgentMessage(messageType: .planUpdateConfirmation, sender: sender, recipient: "ConversationAgent", content: message)
    }
    
    /// Create a request to query the plan
    /// - Parameter query: The query string
    /// - Returns: An AgentMessage
    static func requestPlanQuery(query: String, sender: String = "ConversationAgent") -> AgentMessage {
        return AgentMessage(messageType: .requestPlanQuery, sender: sender, recipient: "PlanningAgent", content: query)
    }
    
    /// Create a plan query result
    /// - Parameter result: The query result
    /// - Returns: An AgentMessage
    static func planQueryResult(result: String, sender: String = "PlanningAgent") -> AgentMessage {
        return AgentMessage(messageType: .planQueryResult, sender: sender, recipient: "ConversationAgent", content: result)
    }
    
    /// Create a request for a plan summary
    /// - Returns: An AgentMessage
    static func requestPlanSummary(sender: String = "ConversationAgent") -> AgentMessage {
        return AgentMessage(messageType: .requestPlanSummary, sender: sender, recipient: "PlanningAgent", content: "")
    }
    
    /// Create a plan summary result
    /// - Parameter summary: The plan summary
    /// - Returns: An AgentMessage
    static func planSummaryResult(summary: String, sender: String = "PlanningAgent") -> AgentMessage {
        return AgentMessage(messageType: .planSummaryResult, sender: sender, recipient: "ConversationAgent", content: summary)
    }
    
    /// Create a request for project context
    /// - Returns: An AgentMessage
    static func requestProjectContext(sender: String = "ConversationAgent") -> AgentMessage {
        return AgentMessage(messageType: .requestProjectContext, sender: sender, recipient: "PlanningAgent", content: "")
    }
    
    /// Create a project context result
    /// - Parameter context: The project context
    /// - Returns: An AgentMessage
    static func projectContextResult(context: String, sender: String = "PlanningAgent") -> AgentMessage {
        return AgentMessage(messageType: .projectContextResult, sender: sender, recipient: "ConversationAgent", content: context)
    }
    
    /// Create an error message
    /// - Parameter errorMessage: The error message
    /// - Returns: An AgentMessage
    static func error(errorMessage: String, sender: String = "System") -> AgentMessage {
        return AgentMessage(messageType: .error, sender: sender, recipient: "ConversationAgent", content: errorMessage)
    }
}
