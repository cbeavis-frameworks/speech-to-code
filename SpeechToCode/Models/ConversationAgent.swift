import Foundation
import AVFoundation
import Combine

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
    private var realtimeSession: RealtimeSession?
    private var planningAgent: PlanningAgent?
    private var terminalController: TerminalController?
    private weak var orchestrator: AgentOrchestrator?
    private var contextManager: ContextManager?
    
    /// Set the planning agent
    /// - Parameter agent: The planning agent to use
    func setPlanningAgent(_ agent: PlanningAgent) {
        self.planningAgent = agent
    }
    
    /// Set the terminal controller
    /// - Parameter controller: The terminal controller to use
    func setTerminalController(_ controller: TerminalController) {
        self.terminalController = controller
    }
    
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
    
    /// Cleanup resources
    private var cancellables = Set<AnyCancellable>()
    
    /// Maximum number of messages to keep in memory
    private let maxMessagesInMemory = 50
    
    /// Minimum messages to retain for context
    private let minMessagesForContext = 10
    
    /// Initialize a new Conversation Agent
    init() {
        // Initialize with default state
        setupMessageHandlers()
    }
    
    /// Connect to an Orchestrator
    /// - Parameter orchestrator: The agent orchestrator to connect to
    func connectToOrchestrator(_ orchestrator: AgentOrchestrator) {
        self.orchestrator = orchestrator
    }
    
    /// Connect to a Realtime Session
    /// - Parameter session: The Realtime session to connect to
    func connectToRealtimeSession(_ session: RealtimeSession) {
        self.realtimeSession = session
        session.delegate = self
        setupRealtimeSessionHandlers()
    }
    
    /// Connect to a Planning Agent
    /// - Parameter agent: The planning agent to connect
    func connectToPlanningAgent(_ agent: PlanningAgent) {
        self.planningAgent = agent
    }
    
    /// Connect to a Context Manager
    /// - Parameter manager: The context manager to connect
    func connectToContextManager(_ manager: ContextManager) {
        self.contextManager = manager
    }
    
    /// Connect to a Terminal Controller
    /// - Parameter controller: The Terminal controller to connect to
    func connectToTerminalController(_ controller: TerminalController) {
        self.terminalController = controller
    }
    
    /// Set up handlers to respond to Realtime session events
    private func setupRealtimeSessionHandlers() {
        guard let realtimeSession = realtimeSession else { return }
        
        // Subscribe to session state changes
        realtimeSession.$sessionState
            .sink { [weak self] sessionState in
                guard let self = self else { return }
                
                switch sessionState {
                case .error(let message):
                    self.state = .error("Realtime session error: \(message)")
                case .disconnected:
                    if self.listeningForVoice {
                        self.stopListening()
                    }
                    if case .processing = self.state {
                        self.state = .idle
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
            
        // Subscribe to transcription updates
        realtimeSession.$currentTranscription
            .sink { [weak self] transcription in
                guard let self = self else { return }
                self.currentTranscription = transcription
            }
            .store(in: &cancellables)
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
        if active && !listeningForVoice && voiceActivationEnabled {
            // Auto-start listening if voice activity detected and not already listening
            Task {
                _ = await startListening()
            }
        }
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
        switch state {
        case .error(let message):
            DispatchQueue.main.async {
                self.state = .error("Realtime session error: \(message)")
            }
        case .disconnected:
            DispatchQueue.main.async {
                if self.listeningForVoice {
                    self.stopListening()
                }
            }
        default:
            break
        }
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
        
        // Create a task ID with the orchestrator if available
        let taskId = orchestrator?.addPendingTask()
        
        // Stop listening to get the final transcription
        realtimeSession.stopListening()
        
        // Get the final transcription
        let finalTranscription = currentTranscription
        
        // Create a voice input message
        let voiceMessage = AgentMessage.voiceInput(transcription: finalTranscription)
        
        // Add the message to our messages array
        DispatchQueue.main.async {
            self.messages.append(voiceMessage)
        }
        
        // Send the transcription to the Realtime API
        let success = await realtimeSession.sendUserMessage(content: finalTranscription)
        
        // Complete the task if we have an orchestrator
        if let taskId = taskId {
            orchestrator?.completePendingTask(taskId)
        }
        
        // Reset processing flag
        isProcessingInput = false
        return success
    }
    
    /// Starts listening for voice commands
    /// - Returns: Boolean indicating success
    @discardableResult
    func startListening() async -> Bool {
        guard let realtimeSession = realtimeSession, 
              !listeningForVoice, !isProcessingInput else {
            return false
        }
        
        // Set state to listening
        DispatchQueue.main.async {
            self.state = .listeningForVoice
            self.listeningForVoice = true
            self.isListening = true
        }
        
        // Start listening via realtime session
        let success =  realtimeSession.startListening()
        
        if !success {
            DispatchQueue.main.async {
                self.state = .idle
                self.listeningForVoice = false
                self.isListening = false
            }
        }
        
        return success
    }
    
    /// Stops listening for voice commands
    func stopListening() {
        guard let realtimeSession = realtimeSession, listeningForVoice else {
            return
        }
        
        // Stop listening via realtime session
        realtimeSession.stopListening()
        
        // Reset listening state
        DispatchQueue.main.async {
            self.listeningForVoice = false
            self.isListening = false
            self.currentTranscription = ""
            self.state = .idle
        }
    }
    
    /// Toggle voice listening state
    /// - Returns: Boolean indicating if listening is now active
    func toggleListening() async -> Bool {
        if listeningForVoice {
            stopListening()
            return false
        } else {
            return await startListening()
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
        
        // Create task ID with orchestrator if available
        let taskId = orchestrator?.addPendingTask()
        
        // Create user input message
        let userMessage = AgentMessage.userInput(content: userInput)
        
        // Add message to our messages array
        DispatchQueue.main.async {
            self.messages.append(userMessage)
        }
        
        var success = false
        
        // Send user input to Realtime API
        if let realtimeSession = realtimeSession {
            success = await realtimeSession.sendUserMessage(content: userInput)
        }
        
        // Complete task if we have an orchestrator
        if let taskId = taskId {
            orchestrator?.completePendingTask(taskId)
        }
        
        // Return to idle state if no longer processing
        if case .processing = state {
            DispatchQueue.main.async {
                self.state = .idle
            }
        }
        
        return success
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
            if let realtimeSession = self.realtimeSession {
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
            if let realtimeSession = self.realtimeSession {
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
            if let realtimeSession = self.realtimeSession {
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
            if let realtimeSession = self.realtimeSession {
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
    
    /// Generate a summary of the conversation for context
    /// - Returns: Summarized conversation history
    func generateConversationSummary() async -> String {
        let messageCount = messages.count
        
        // If we have no messages, return an empty summary
        if messageCount == 0 {
            return "No conversation history yet."
        }
        
        // Calculate how many messages to include in the summary
        let messagesToInclude = min(maxMessagesInMemory, max(messageCount, minMessagesForContext))
        let startIndex = max(0, messageCount - messagesToInclude)
        
        // Create the summary
        var summary = "# Conversation History\n\n"
        summary += "Last \(messagesToInclude) messages as of \(Date()):\n\n"
        
        // Add recent messages to the summary, focusing on user inputs and assistant outputs
        for i in startIndex..<messageCount {
            let message = messages[i]
            
            switch message.messageType {
            case .userInput, .voiceInput:
                summary += "**User**: \(message.content)\n\n"
            case .assistantOutput, .voiceOutput:
                summary += "**Assistant**: \(message.content)\n\n"
            case .terminalCommand:
                summary += "**Command**: \(message.content)\n\n"
            case .terminalOutput:
                // For terminal output, include a condensed version to save space
                let condensedOutput = condenseTerminalOutput(message.content)
                summary += "**Output**: \(condensedOutput)\n\n"
            default:
                // Skip other message types to focus on the conversation
                continue
            }
        }
        
        return summary
    }
    
    /// Condense terminal output to save space in context
    /// - Parameter output: The terminal output
    /// - Returns: Condensed terminal output
    private func condenseTerminalOutput(_ output: String) -> String {
        // If the output is short, return it as is
        if output.count < 100 {
            return output
        }
        
        // Otherwise, create a condensed version with first and last few lines
        let lines = output.components(separatedBy: "\n")
        
        // If there aren't many lines, return a slightly truncated version
        if lines.count < 10 {
            return output.prefix(200) + (output.count > 200 ? "..." : "")
        }
        
        // For longer outputs, take first 3 and last 3 lines
        let firstLines = lines.prefix(3).joined(separator: "\n")
        let lastLines = lines.suffix(3).joined(separator: "\n")
        
        return "\(firstLines)\n...\n\(lastLines)"
    }
    
    /// Get combined context from the context manager
    /// - Returns: Combined context for the agent
    func getCombinedContext() async -> String {
        // If we don't have a context manager, create conversation context only
        guard let contextManager = contextManager else {
            return await generateConversationSummary()
        }
        
        // Get context from context manager
        let contextTypes: [ContextManager.ContextType] = [.project, .conversation, .taskStatus, .codeStructure]
        return contextManager.getCombinedContext(types: contextTypes)
    }
    
    /// Refresh all context from the manager
    /// - Returns: Success indicator
    @discardableResult
    func refreshContext() async -> Bool {
        guard let contextManager = contextManager else {
            return false
        }
        
        // Generate a new conversation summary
        let conversationSummary = await generateConversationSummary()
        
        // Update it in the context manager
        contextManager.updateContextSummary(conversationSummary, type: .conversation)
        
        // Request a full context refresh
        return await contextManager.refreshContextForAgents()
    }
    
    /// Process an agent message with context
    /// - Parameter message: The message to process
    /// - Returns: Response with context incorporated
    func processMessageWithContext(_ message: AgentMessage) async -> AgentMessage {
        // Get the combined context
        let context = await getCombinedContext()
        
        // Create metadata with context
        var metadata = message.metadata
        metadata["context"] = context
        
        // Create new message with the context metadata
        let contextualMessage = AgentMessage(
            messageType: message.messageType,
            sender: message.sender,
            recipient: message.recipient,
            content: message.content,
            metadata: metadata
        )
        
        // Process the message with context
        return await processIncomingAgentMessage(contextualMessage)
    }
}
