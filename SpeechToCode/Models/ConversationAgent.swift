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
    private var planningAgent: Any?
    private var terminalController: Any? // Using Any since we don't have the actual type yet
    
    /// Voice processing configuration
    private var voiceActivationEnabled: Bool = true
    private var autoCommitAfterSilence: Bool = true
    private var interruptibleResponses: Bool = true
    
    /// Flag to track if input is being processed
    private var isProcessingInput: Bool = false
    
    /// Flag to track if listening for voice
    private var listeningForVoice: Bool = false
    
    /// Initialize a new Conversation Agent
    init() {
        // Initialize with default state
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
    func connectToPlanningAgent(_ agent: Any) {
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
        
        // Also inform planning agent if available
        if let planningAgent = planningAgent as? PlanningAgent {
            planningAgent.processUserInput(userInput)
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
}
