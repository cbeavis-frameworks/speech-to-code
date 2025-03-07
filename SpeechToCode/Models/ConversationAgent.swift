import Foundation

/// Conversation agent model to handle user interaction and orchestrate workflow
class ConversationAgent: ObservableObject {
    /// Current state of the agent
    enum AgentState {
        case idle
        case processing
        case error(String)
    }
    
    /// Published properties for SwiftUI integration
    @Published var state: AgentState = .idle
    @Published var messages: [AgentMessage] = []
    
    /// References to other components
    private var realtimeSession: RealtimeSession?
    private var planningAgent: PlanningAgent?
    private var terminalController: Any? // Using Any since we don't have the actual type yet
    
    /// Initialize a new Conversation Agent
    init() {
        // Initialize with default state
    }
    
    /// Connect to a Realtime Session
    /// - Parameter session: The Realtime session to connect to
    func connectToRealtimeSession(_ session: RealtimeSession) {
        self.realtimeSession = session
    }
    
    /// Connect to a Planning Agent
    /// - Parameter agent: The Planning agent to connect to
    func connectToPlanningAgent(_ agent: PlanningAgent) {
        self.planningAgent = agent
    }
    
    /// Connect to a Terminal Controller
    /// - Parameter controller: The Terminal controller to connect to
    func connectToTerminalController(_ controller: Any) {
        self.terminalController = controller
    }
    
    /// Process user input
    /// - Parameter userInput: The user input text
    /// - Returns: Success indicator
    func processUserInput(_ userInput: String) async -> Bool {
        // Start processing
        state = .processing
        
        // Create a user input message
        let userMessage = AgentMessage.userInput(userInput)
        
        DispatchQueue.main.async {
            self.messages.append(userMessage)
        }
        
        // Forward to Realtime session (if available)
        if let realtimeSession = realtimeSession {
            let success = await realtimeSession.sendUserMessage(userInput)
            if !success {
                state = .error("Failed to send message to Realtime session")
                return false
            }
        }
        
        // Also inform planning agent if available
        if let planningAgent = planningAgent {
            planningAgent.processUserInput(userInput)
        }
        
        // Return to idle state
        state = .idle
        return true
    }
    
    /// Process a terminal command
    /// - Parameter command: The terminal command to execute
    /// - Returns: Success indicator
    func executeTerminalCommand(_ command: String) async -> Bool {
        // Create a terminal command message
        let commandMessage = AgentMessage(
            messageType: .terminalCommand,
            sender: "ConversationAgent",
            recipient: "TerminalController",
            content: command
        )
        
        DispatchQueue.main.async {
            self.messages.append(commandMessage)
        }
        
        // Simulate response for testing
        let responseMessage = AgentMessage(
            messageType: .terminalResponse,
            sender: "TerminalController",
            recipient: "ConversationAgent",
            content: "[TEST MODE] Executed command: \(command)"
        )
        
        DispatchQueue.main.async {
            self.messages.append(responseMessage)
        }
        
        return true
    }
    
    /// Process a function call
    /// - Parameters:
    ///   - functionName: The function name
    ///   - arguments: Function arguments
    /// - Returns: Success indicator
    func processFunctionCall(_ functionName: String, arguments: [String: Any]) async -> Bool {
        // Create a function call message
        let functionMessage = AgentMessage(
            messageType: .functionCall,
            sender: "ConversationAgent",
            recipient: "System",
            content: functionName,
            metadata: ["arguments": arguments.description]
        )
        
        DispatchQueue.main.async {
            self.messages.append(functionMessage)
        }
        
        // Simulate result for testing
        let resultMessage = AgentMessage(
            messageType: .functionResult,
            sender: "System",
            recipient: "ConversationAgent",
            content: "[TEST MODE] Function result for: \(functionName)",
            metadata: ["function": functionName]
        )
        
        DispatchQueue.main.async {
            self.messages.append(resultMessage)
        }
        
        return true
    }
}
