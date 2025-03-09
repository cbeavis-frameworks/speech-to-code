import Foundation
import AVFoundation

/// Conversation agent model to handle user interaction and orchestrate workflow
@available(macOS 10.15, *)
class ConversationAgent: ObservableObject, VoiceProcessorDelegate, RealtimeSessionDelegate, @unchecked Sendable {
    /// Current state of the agent
    enum AgentState {
        case idle
        case processing
        case listeningForVoice
        case processingVoice
        case speaking
        case error(String)
    }
    
    /// Published properties for SwiftUI integration
    @Published var state: AgentState = .idle
    @Published var messages: [AgentMessage] = []
    @Published var currentTranscription: String = ""
    @Published var isListening: Bool = false
    @Published var audioLevel: Float = 0.0
    
    /// References to other components
    private var realtimeSession: Any?
    private var planningAgent: PlanningAgent?
    private var terminalController: Any? // Using Any since we don't have the actual type yet
    
    /// Voice processing configuration
    private var voiceActivationEnabled: Bool = true
    private var autoCommitAfterSilence: Bool = true
    private var interruptibleResponses: Bool = true
    
    /// Flag to track if input is being processed
    private var isProcessingInput: Bool = false
    
    /// Flag to track if listening for voice
    private var listeningForVoice: Bool = false
    
    /// Agent communication message handler
    private var messageHandlers: [AgentMessage.MessageType: (AgentMessage) async -> AgentMessage] = [:]
    
    /// Initialize a new Conversation Agent
    init() {
        // Initialize with default state
        setupMessageHandlers()
    }
    
    /// Connect to a Realtime Session
    /// - Parameter session: The Realtime session to connect to
    func connectToRealtimeSession(_ session: Any) {
        self.realtimeSession = session
    }
    
    /// Set up handlers to respond to Realtime session events
    private func setupRealtimeSessionHandlers() {
        // Implementation will be updated once we fix the build errors
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
    
    // MARK: - VoiceProcessorDelegate Methods
    
    func voiceProcessor(_ processor: VoiceProcessor, didCaptureTranscription text: String) {
        currentTranscription = text
        
        if case .listeningForVoice = state {
            if !text.isEmpty {
                state = .processingVoice
            }
        }
    }
    
    func voiceProcessor(_ processor: VoiceProcessor, didDetectVoiceActivity active: Bool) {
        // Update UI or state based on voice activity detection
    }
    
    func voiceProcessor(_ processor: VoiceProcessor, didChangeAudioLevel level: Float) {
        DispatchQueue.main.async {
            self.audioLevel = level
        }
    }
    
    // MARK: - RealtimeSessionDelegate Methods
    
    func realtimeSession(_ session: RealtimeSession, didReceiveTranscription text: String) {
        DispatchQueue.main.async {
            self.currentTranscription = text
        }
    }
    
    func realtimeSession(_ session: RealtimeSession, didChangeState state: RealtimeSession.SessionState) {
        // Handle state changes
    }
    
    func realtimeSession(_ session: RealtimeSession, didReceiveMessage message: AgentMessage) {
        DispatchQueue.main.async {
            self.messages.append(message)
            
            // Process the message using our communication system
            Task {
                _ = await self.processIncomingAgentMessage(message)
            }
        }
    }
    
    // MARK: - Voice Processing Methods
    
    /// Processes voice commands using macOS Speech Recognition
    /// - Returns: Boolean indicating if the command was processed successfully
    func processVoiceCommand() async -> Bool {
        guard let realtimeSession = realtimeSession, !isProcessingInput else {
            return false
        }
        
        // Set the input processing flag
        isProcessingInput = true
        
        // Stop listening to get the final transcription
        if let session = realtimeSession as? RealtimeSession {
            session.stopListening()
        }
        
        // Reset processing flag
        isProcessingInput = false
        return true
    }
    
    /// Starts listening for voice commands
    /// - Returns: Boolean indicating success
    func startListening() -> Bool {
        guard let realtimeSession = realtimeSession, 
              !listeningForVoice, !isProcessingInput else {
            return false
        }
        
        // Set listening state
        listeningForVoice = true
        
        // Register for transcription updates
        if let session = realtimeSession as? RealtimeSession {
            session.onTranscription { [weak self] (transcription: String) in
                guard let self = self else { return }
                self.currentTranscription = transcription
            }
        }
        
        // Start listening via realtime session
        if let session = realtimeSession as? RealtimeSession {
            let success = session.startListening()
            if !success {
                listeningForVoice = false
            }
        }
        
        return true
    }
    
    /// Stops listening for voice commands
    func stopListening() {
        guard let realtimeSession = realtimeSession, listeningForVoice else {
            return
        }
        
        // Stop listening via realtime session
        if let session = realtimeSession as? RealtimeSession {
            session.stopListening()
        }
        
        // Reset listening state
        listeningForVoice = false
        currentTranscription = ""
    }
    
    /// Toggle voice listening state
    /// - Returns: Boolean indicating if listening is now active
    func toggleListening() -> Bool {
        if listeningForVoice {
            stopListening()
            return false
        } else {
            return startListening()
        }
    }
    
    /// Process user input
    /// - Parameter userInput: The user input text
    /// - Returns: Success indicator
    func processUserInput(_ userInput: String) async -> Bool {
        // Start processing
        DispatchQueue.main.async {
            self.state = .processing
        }
        
        // Create a user input message
        let userMessage = AgentMessage.userInput(content: userInput)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.messages.append(userMessage)
        }
        
        // Check if this input should be routed to PlanningAgent
        if userInput.lowercased().contains("plan") || 
           userInput.lowercased().contains("task") ||
           userInput.lowercased().contains("context") {
            
            await requestProjectContextFromPlanningAgent()
        }
        
        // Forward to Realtime session (if available)
        if let realtimeSession = realtimeSession as? RealtimeSession {
            let success = await realtimeSession.sendUserMessage(content: userInput)
            if !success {
                DispatchQueue.main.async {
                    self.state = .error("Failed to send message to Realtime session")
                }
                return false
            }
        }
        
        // Return to idle state
        DispatchQueue.main.async {
            self.state = .idle
        }
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
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.messages.append(commandMessage)
        }
        
        // Simulate response for testing
        let responseMessage = AgentMessage(
            messageType: .terminalOutput,
            sender: "TerminalController",
            recipient: "ConversationAgent",
            content: "[TEST MODE] Executed command: \(command)"
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
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
            messageType: .planningRequest,
            sender: "ConversationAgent",
            recipient: "System",
            content: functionName,
            metadata: ["arguments": arguments.description]
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.messages.append(functionMessage)
        }
        
        // Simulate result for testing
        let resultMessage = AgentMessage(
            messageType: .planningResponse,
            sender: "System",
            recipient: "ConversationAgent",
            content: "[TEST MODE] Function result for: \(functionName)",
            metadata: ["function": functionName]
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.messages.append(resultMessage)
        }
        
        return true
    }
    
    // MARK: - Configuration Methods
    
    /// Configure voice activation settings
    /// - Parameters:
    ///   - enabled: Whether voice activation is enabled
    ///   - autoCommit: Whether to automatically commit the buffer after silence
    ///   - interruptible: Whether responses can be interrupted
    func configureVoiceActivation(enabled: Bool, autoCommit: Bool, interruptible: Bool) {
        voiceActivationEnabled = enabled
        autoCommitAfterSilence = autoCommit
        interruptibleResponses = interruptible
    }
    
    // MARK: - Agent Communication Methods
    
    /// Set up message handlers for agent communication
    private func setupMessageHandlers() {
        // Define handlers for each message type
        messageHandlers[.planQueryResult] = { [weak self] message in
            // Handle plan query result
            guard let self = self else { 
                return AgentMessage(
                    messageType: .error,
                    sender: "ConversationAgent",
                    recipient: message.sender,
                    content: "Self reference lost"
                )
            }
            
            // Log the result and potentially send to Realtime API
            if let realtimeSession = self.realtimeSession as? RealtimeSession {
                // Format the plan info nicely for the user
                let formattedContent = "📋 Plan Information:\n\(message.content)"
                Task {
                    await realtimeSession.sendAssistantMessage(content: formattedContent)
                }
            }
            
            // Return acknowledgment message
            return AgentMessage(
                messageType: .assistantOutput,
                sender: "ConversationAgent",
                recipient: message.sender,
                content: "Received plan query result",
                metadata: ["processed": "true"]
            )
        }
        
        messageHandlers[.planUpdateConfirmation] = { [weak self] message in
            // Handle plan update confirmation
            guard let self = self else { 
                return AgentMessage(
                    messageType: .error,
                    sender: "ConversationAgent",
                    recipient: message.sender,
                    content: "Self reference lost"
                )
            }
            
            // Notify the user
            if let realtimeSession = self.realtimeSession as? RealtimeSession {
                Task {
                    await realtimeSession.sendAssistantMessage(content: "✅ " + message.content)
                }
            }
            
            // Return acknowledgment message
            return AgentMessage(
                messageType: .assistantOutput,
                sender: "ConversationAgent",
                recipient: message.sender,
                content: "Acknowledged plan update",
                metadata: ["processed": "true"]
            )
        }
        
        messageHandlers[.planSummaryResult] = { [weak self] message in
            // Handle plan summary result
            guard let self = self else { 
                return AgentMessage(
                    messageType: .error,
                    sender: "ConversationAgent",
                    recipient: message.sender,
                    content: "Self reference lost"
                )
            }
            
            // Format and send to user
            if let realtimeSession = self.realtimeSession as? RealtimeSession {
                let formattedContent = "📊 Plan Summary:\n\(message.content)"
                Task {
                    await realtimeSession.sendAssistantMessage(content: formattedContent)
                }
            }
            
            // Return acknowledgment message
            return AgentMessage(
                messageType: .assistantOutput,
                sender: "ConversationAgent",
                recipient: message.sender,
                content: "Received plan summary",
                metadata: ["processed": "true"]
            )
        }
        
        messageHandlers[.projectContextResult] = { [weak self] message in
            // Handle project context result
            guard let self = self else { 
                return AgentMessage(
                    messageType: .error,
                    sender: "ConversationAgent",
                    recipient: message.sender,
                    content: "Self reference lost"
                )
            }
            
            // Use the project context in our communication with the user
            if let realtimeSession = self.realtimeSession as? RealtimeSession {
                Task {
                    // Enhance with project context rather than just forwarding directly
                    await realtimeSession.setContext(message.content)
                }
            }
            
            // Return acknowledgment message
            return AgentMessage(
                messageType: .assistantOutput,
                sender: "ConversationAgent",
                recipient: message.sender,
                content: "Received project context",
                metadata: ["processed": "true"]
            )
        }
        
        messageHandlers[.error] = { [weak self] message in
            // Handle error message
            guard let self = self else { 
                return AgentMessage(
                    messageType: .error,
                    sender: "ConversationAgent",
                    recipient: message.sender,
                    content: "Self reference lost"
                )
            }
            
            DispatchQueue.main.async {
                self.state = .error(message.content)
            }
            
            // Log but don't necessarily forward to user
            print("Error from \(message.sender): \(message.content)")
            
            // Return acknowledgment
            return AgentMessage(
                messageType: .error,
                sender: "ConversationAgent",
                recipient: message.sender,
                content: "Error acknowledged: \(message.content)",
                metadata: ["processed": "true"]
            )
        }
    }
    
    /// Process an incoming agent message
    /// - Parameter message: The message to process
    /// - Returns: Response message, if any
    func processIncomingAgentMessage(_ message: AgentMessage) async -> AgentMessage {
        // Check if we have a handler for this message type
        if let handler = messageHandlers[message.messageType] {
            return await handler(message)
        } else {
            // Default handler for unhandled message types
            print("Unhandled message type: \(message.messageType)")
            return AgentMessage(
                messageType: .error,
                sender: "ConversationAgent",
                recipient: message.sender,
                content: "Unhandled message type: \(message.messageType)",
                metadata: ["processed": "false"]
            )
        }
    }
    
    /// Send a message to another agent
    /// - Parameters:
    ///   - message: The message to send
    ///   - recipient: The recipient agent
    /// - Returns: Response message, if any
    @discardableResult
    func sendAgentMessage(_ message: AgentMessage) async -> AgentMessage? {
        // Add to our message log
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.messages.append(message)
        }
        
        // Route to appropriate agent
        switch message.recipient {
        case "PlanningAgent":
            // Route to planning agent
            if let planningAgent = planningAgent {
                let response = planningAgent.processAgentMessage(message)
                
                // Add response to message log
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.messages.append(response)
                }
                
                // Process the response and discard the result
                _ = await processIncomingAgentMessage(response)
                
                return response
            }
        default:
            print("Unknown recipient: \(message.recipient)")
        }
        
        return nil
    }
    
    /// Request project context from the planning agent
    /// - Returns: Project context
    @discardableResult
    func requestProjectContextFromPlanningAgent() async -> String? {
        // Create a project context request
        let contextRequest = AgentMessage.requestProjectContext(sender: "ConversationAgent")
        
        // Send to planning agent
        let response = await sendAgentMessage(contextRequest)
        
        // Return the context if valid
        if let response = response, response.messageType == .projectContextResult {
            return response.content
        }
        
        return nil
    }
    
    /// Request a plan update
    /// - Parameter updateDetails: Plan update details
    /// - Returns: Success indicator
    @discardableResult
    func requestPlanUpdate(_ updateDetails: String) async -> Bool {
        // Create plan update request
        let updateRequest = AgentMessage.requestPlanUpdate(content: updateDetails, sender: "ConversationAgent")
        
        // Send to planning agent
        let response = await sendAgentMessage(updateRequest)
        
        // Check response
        if let response = response, response.messageType == .planUpdateConfirmation {
            return true
        }
        
        return false
    }
    
    /// Request a plan query
    /// - Parameter query: The query string
    /// - Returns: Query result
    @discardableResult
    func queryPlan(_ query: String) async -> String? {
        // Create a plan query request
        let queryRequest = AgentMessage.requestPlanQuery(query: query, sender: "ConversationAgent")
        
        // Send to planning agent
        let response = await sendAgentMessage(queryRequest)
        
        // Return the query result if valid
        if let response = response, response.messageType == .planQueryResult {
            return response.content
        }
        
        return nil
    }
    
    /// Request a plan summary
    /// - Returns: Plan summary
    @discardableResult
    func requestPlanSummary() async -> String? {
        // Create a plan summary request
        let summaryRequest = AgentMessage.requestPlanSummary(sender: "ConversationAgent")
        
        // Send to planning agent
        let response = await sendAgentMessage(summaryRequest)
        
        // Return the summary if valid
        if let response = response, response.messageType == .planSummaryResult {
            return response.content
        }
        
        return nil
    }
}
