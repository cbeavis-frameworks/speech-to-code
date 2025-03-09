import Foundation
import NIO
import WebSocketKit
import NIOHTTP1
import AsyncHTTPClient
import NIOFoundationCompat
import AVFoundation

/// Protocol for RealtimeSession delegates
protocol RealtimeSessionDelegate: AnyObject {
    /// Called when transcription is received
    /// - Parameters:
    ///   - session: The session that received the transcription
    ///   - text: The transcribed text
    func realtimeSession(_ session: RealtimeSession, didReceiveTranscription text: String)
    
    /// Called when session state changes
    /// - Parameters:
    ///   - session: The session that changed state
    ///   - state: The new state
    func realtimeSession(_ session: RealtimeSession, didChangeState state: RealtimeSession.SessionState)
    
    /// Called when a message is received
    /// - Parameters:
    ///   - session: The session that received the message
    ///   - message: The received message
    func realtimeSession(_ session: RealtimeSession, didReceiveMessage message: AgentMessage)
}

/// Model for managing OpenAI Realtime API sessions
@available(macOS 10.15, *)
class RealtimeSession: ObservableObject, @unchecked Sendable {
    /// Current state of the Realtime session
    enum SessionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
        
        static func == (lhs: SessionState, rhs: SessionState) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected):
                return true
            case (.connecting, .connecting):
                return true
            case (.connected, .connected):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    /// Published properties for SwiftUI integration
    @Published var sessionState: SessionState = .disconnected
    @Published var messages: [AgentMessage] = []
    @Published var isListening: Bool = false
    @Published var isProcessingVoice: Bool = false
    @Published var currentTranscription: String = ""
    
    /// Session configuration
    private var apiKey: String
    private var modelId: String
    private var sessionId: String?
    private var websocket: WebSocket?
    private var eventLoopGroup: EventLoopGroup?
    
    // Use the external configuration
    private var config: RealtimeSessionConfig
    
    // Voice processing
    private var voiceProcessor: VoiceProcessor?
    private var isVoiceActivated: Bool = false
    
    // Completion handlers for async events
    private var messageHandlers: [(AgentMessage) -> Void] = []
    private var functionCallHandlers: [(String, [String: Any]) -> Void] = []
    private var transcriptionHandlers: [(String) -> Void] = []
    
    weak var delegate: RealtimeSessionDelegate?
    
    /// Initialize a new Realtime session
    /// - Parameters:
    ///   - apiKey: The OpenAI API key (if nil, will be retrieved from Config)
    ///   - modelId: The model ID to use (defaults to GPT-4o Realtime)
    ///   - config: Configuration options for the session
    init(apiKey: String? = nil, modelId: String = "gpt-4o-realtime-preview-2024-12-17", config: RealtimeSessionConfig = .default) {
        self.apiKey = apiKey ?? Config.OpenAI.apiKey
        self.modelId = modelId
        self.config = config
        
        _ = setupVoiceProcessor()
    }
    
    /// Configure and start the voice processor
    /// - Returns: Boolean indicating success
    private func setupVoiceProcessor() -> Bool {
        voiceProcessor = VoiceProcessor()
        
        guard let voiceProcessor = voiceProcessor else {
            return false
        }
        
        // Set up handlers for voice processor events
        voiceProcessor.onTranscription { [weak self] transcription in
            guard let self = self else { return }
            self.currentTranscription = transcription
            
            // Notify all registered handlers
            for handler in self.transcriptionHandlers {
                handler(transcription)
            }
        }
        
        return true
    }
    
    /// Connect to the OpenAI Realtime API
    /// - Returns: A boolean indicating success
    func connect() async -> Bool {
        guard sessionState == .disconnected else {
            if sessionState == .connected {
                return true // Already connected
            }
            return false
        }
        
        // Update state to connecting
        DispatchQueue.main.async { [self] in
            self.sessionState = .connecting
        }
        
        // Create event loop group for the WebSocket
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        guard let eventLoopGroup = eventLoopGroup else {
            DispatchQueue.main.async {
                self.sessionState = .error("Failed to create event loop group")
            }
            return false
        }
        
        // Construct the WebSocket URL with model parameter
        let wsURL = "wss://api.openai.com/v1/realtime?model=\(modelId)"
        
        // Connect to WebSocket
        let webSocketPromise = WebSocketKit.WebSocket.connect(
            to: wsURL,
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "OpenAI-Beta": "realtime=v1"
            ],
            configuration: .init(),
            on: eventLoopGroup
        ) { [weak self] ws in
            guard let self = self else { return }
            self.websocket = ws
            
            // Set up message handler
            ws.onText { [weak self] _, text in
                guard let self = self else { return }
                self.handleWebSocketMessage(text)
            }
            
            // Set up close handler
            ws.onClose.whenComplete { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self.sessionState = .disconnected
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.sessionState = .error("WebSocket closed with error: \(error.localizedDescription)")
                    }
                }
            }
            
            // Update state to connected
            DispatchQueue.main.async {
                self.sessionState = .connected
            }
            
            // Configure the session
            self.configureSession()
        }
        
        // Wait for connection to complete or fail
        do {
            _ = try await webSocketPromise.get()
            return true
        } catch {
            DispatchQueue.main.async { [self] in
                self.sessionState = .error("Failed to connect: \(error.localizedDescription)")
            }
            return false
        }
    }
    
    /// Configure the session with initial settings
    private func configureSession() {
        guard let websocket = websocket else { return }
        
        // Create session update event
        let sessionUpdateEvent: [String: Any] = [
            "type": "session.update",
            "session": [
                "instructions": config.instructions,
                "modalities": config.modalities,
                "voice": config.voice,
                "temperature": config.temperature,
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "turn_detection": [
                    "mode": "client_vad"
                ]
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sessionUpdateEvent)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                websocket.send(jsonString)
            }
        } catch {
            print("Error creating session update: \(error)")
        }
    }
    
    /// Send a message to the server (non-async version for callbacks)
    /// - Parameter message: The message to send
    private func sendMessage(_ message: String) {
        guard let websocket = websocket, sessionState == .connected else {
            return
        }
        
        websocket.send(message)
    }
    
    /// Handle incoming WebSocket messages
    /// - Parameter text: The message text
    private func handleWebSocketMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let eventType = json["type"] as? String {
                
                switch eventType {
                case "session.created", "session.updated":
                    handleSessionEvent(json)
                    
                case "response.text.delta":
                    handleTextDelta(json)
                    
                case "response.function_call.delta":
                    handleFunctionCallDelta(json)
                    
                case "response.done":
                    handleResponseDone(json)
                    
                case "conversation.item.input_audio_transcription.completed":
                    // This event is no longer needed with the new Speech Recognition approach
                    break
                
                default:
                    print("Unhandled event type: \(eventType)")
                }
            }
        } catch {
            print("Error parsing WebSocket message: \(error)")
        }
    }
    
    /// Handle session events (created or updated)
    /// - Parameter json: The event JSON
    private func handleSessionEvent(_ json: [String: Any]) {
        if let eventType = json["type"] as? String,
           let sessionData = json["session"] as? [String: Any],
           let sessionId = sessionData["id"] as? String {
            
            self.sessionId = sessionId
            
            // Log session event
            print("Session event: \(eventType), ID: \(sessionId)")
            
            // Update UI with session info
            DispatchQueue.main.async {
                let message = AgentMessage(
                    messageType: .assistantOutput,
                    sender: "RealtimeSession",
                    recipient: "User",
                    content: "Session \(eventType == "session.created" ? "created" : "updated"): \(sessionId)",
                    metadata: ["sessionId": sessionId]
                )
                self.messages.append(message)
            }
        }
    }
    
    /// Handle text delta events
    /// - Parameter json: The event JSON
    private func handleTextDelta(_ json: [String: Any]) {
        if let responseId = json["response_id"] as? String,
           let delta = json["delta"] as? String {
            
            // Append to the current text buffer
            if let index = messages.lastIndex(where: { $0.metadata["responseId"] == responseId }) {
                // Update existing message
                DispatchQueue.main.async {
                    let lastMessage = self.messages[index]
                    let updatedContent = lastMessage.content + delta
                    
                    let updatedMessage = AgentMessage(
                        messageType: lastMessage.messageType,
                        sender: lastMessage.sender,
                        recipient: lastMessage.recipient,
                        content: updatedContent,
                        metadata: lastMessage.metadata
                    )
                    self.messages[index] = updatedMessage
                    
                    // Notify message handlers of update
                    for handler in self.messageHandlers {
                        handler(updatedMessage)
                    }
                }
            } else {
                // Create new message
                let message = AgentMessage(
                    messageType: .assistantOutput,
                    sender: self.modelId,
                    recipient: "User",
                    content: delta,
                    metadata: ["responseId": responseId]
                )
                
                DispatchQueue.main.async {
                    self.messages.append(message)
                    
                    // Notify handlers
                    for handler in self.messageHandlers {
                        handler(message)
                    }
                }
            }
        }
    }
    
    /// Handle function call delta events
    /// - Parameter json: The event JSON
    private func handleFunctionCallDelta(_ json: [String: Any]) {
        if let responseId = json["response_id"] as? String,
           let delta = json["delta"] as? [String: Any],
           let functionCall = delta["function_call"] as? [String: Any] {
            
            // Extract function name and arguments
            guard let name = functionCall["name"] as? String else { return }
            let arguments = functionCall["arguments"] as? [String: Any] ?? [:]
            
            // Notify function call handlers
            for handler in functionCallHandlers {
                handler(name, arguments)
            }
            
            // Update UI with function call
            DispatchQueue.main.async {
                // Create function call message
                let functionCallContent: String
                if let argsData = try? JSONSerialization.data(withJSONObject: arguments),
                   let argsString = String(data: argsData, encoding: .utf8) {
                    functionCallContent = "Function call: \(name)\nArguments: \(argsString)"
                } else {
                    functionCallContent = "Function call: \(name)"
                }
                
                let functionCallMessage = AgentMessage(
                    messageType: .planningRequest,
                    sender: "RealtimeSession",
                    recipient: "ConversationAgent",
                    content: functionCallContent,
                    metadata: [
                        "responseId": responseId,
                        "function": name
                    ]
                )
                self.messages.append(functionCallMessage)
            }
        }
    }
    
    /// Handle response done events
    /// - Parameter json: The event JSON
    private func handleResponseDone(_ json: [String: Any]) {
        if let responseId = json["response_id"] as? String {
            // Update UI to indicate response completion
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Find the last message with this responseId and mark it complete
                if let lastIndex = self.messages.lastIndex(where: { $0.metadata["responseId"] == responseId }) {
                    var updatedMetadata = self.messages[lastIndex].metadata
                    updatedMetadata["isComplete"] = "true"
                    
                    let updatedMessage = AgentMessage(
                        messageType: self.messages[lastIndex].messageType,
                        sender: self.messages[lastIndex].sender,
                        recipient: self.messages[lastIndex].recipient,
                        content: self.messages[lastIndex].content,
                        metadata: updatedMetadata
                    )
                    self.messages[lastIndex] = updatedMessage
                    
                    // Notify message handlers of completion
                    for handler in self.messageHandlers {
                        handler(updatedMessage)
                    }
                }
            }
        }
    }
    
    /// Start listening for voice input
    /// - Returns: Boolean indicating success
    func startListening() -> Bool {
        guard !isListening else {
            return false
        }
        
        isListening = true
        isProcessingVoice = false
        
        return voiceProcessor?.startRecording() ?? false
    }
    
    /// Stop listening for voice input
    func stopListening() {
        guard isListening else {
            return
        }
        
        isListening = false
        _ = voiceProcessor?.stopRecording()
    }
    
    /// Send a user message to the Realtime API
    /// - Parameter text: The user message text
    /// - Returns: A boolean indicating success
    func sendUserMessage(content text: String) async -> Bool {
        guard let websocket = websocket, sessionState == .connected else {
            return false
        }
        
        // First, create a conversation item event with the user input
        let conversationItemEvent: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [
                    [
                        "type": "input_text",
                        "text": text
                    ]
                ]
            ]
        ]
        
        // Then, create a response event to request a model response
        let responseEvent: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": config.modalities
            ]
        ]
        
        do {
            // Add user message to the UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let userMessage = AgentMessage.userInput(content: text)
                self.messages.append(userMessage)
            }
            
            // Send conversation item event
            let conversationItemData = try JSONSerialization.data(withJSONObject: conversationItemEvent)
            if let conversationItemString = String(data: conversationItemData, encoding: .utf8) {
                try await websocket.send(conversationItemString)
            }
            
            // Send response event
            let responseData = try JSONSerialization.data(withJSONObject: responseEvent)
            if let responseString = String(data: responseData, encoding: .utf8) {
                try await websocket.send(responseString)
            }
            
            return true
        } catch {
            print("Error sending message: \(error)")
            return false
        }
    }
    
    /// Register a handler for transcription updates
    /// - Parameter handler: The callback closure
    func onTranscription(_ handler: @escaping (String) -> Void) {
        transcriptionHandlers.append(handler)
    }
    
    /// Register a handler for new messages
    /// - Parameter handler: A closure to call when a new message is received
    func onMessage(_ handler: @escaping (AgentMessage) -> Void) {
        messageHandlers.append(handler)
    }
    
    /// Register a handler for function calls
    /// - Parameter handler: A closure to call when a function call is received
    func onFunctionCall(_ handler: @escaping (String, [String: Any]) -> Void) {
        functionCallHandlers.append(handler)
    }
    
    /// Request a function call from the model
    /// - Parameters:
    ///   - text: The user prompt
    ///   - functions: Array of function definitions
    ///   - functionCall: Optional specific function to call
    /// - Returns: A boolean indicating success
    func requestFunctionCall(_ text: String, functions: [[String: Any]], functionCall: String? = nil) async -> Bool {
        guard let websocket = websocket, sessionState == .connected else {
            return false
        }
        
        // First, create a conversation item event with the user input
        let conversationItemEvent: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [
                    [
                        "type": "input_text",
                        "text": text
                    ]
                ]
            ]
        ]
        
        // Then, create a response event with function calling capability
        var responseEvent: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": config.modalities,
                "tools": functions
            ]
        ]
        
        // If a specific function call is requested, set tool_choice
        if let functionCall = functionCall {
            var responseDict = (responseEvent["response"] as? [String: Any]) ?? [:]
            responseDict["tool_choice"] = [
                "type": "function",
                "function": [
                    "name": functionCall
                ]
            ]
            responseEvent["response"] = responseDict
        } else {
            var responseDict = (responseEvent["response"] as? [String: Any]) ?? [:]
            responseDict["tool_choice"] = "auto"
            responseEvent["response"] = responseDict
        }
        
        do {
            // Add user message to the UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let userMessage = AgentMessage.userInput(content: text)
                self.messages.append(userMessage)
            }
            
            // Send conversation item event
            let conversationItemData = try JSONSerialization.data(withJSONObject: conversationItemEvent)
            if let conversationItemString = String(data: conversationItemData, encoding: .utf8) {
                try await websocket.send(conversationItemString)
            }
            
            // Send response event
            let responseData = try JSONSerialization.data(withJSONObject: responseEvent)
            if let responseString = String(data: responseData, encoding: .utf8) {
                try await websocket.send(responseString)
            }
            
            return true
        } catch {
            print("Error requesting function call: \(error)")
            return false
        }
    }
    
    /// Send function result back to the model
    /// - Parameters:
    ///   - functionName: The name of the function
    ///   - result: The function result
    ///   - error: Optional error message
    /// - Returns: A boolean indicating success
    func sendFunctionResult(_ functionName: String, result: Any, error: String? = nil) async -> Bool {
        guard let websocket = websocket, sessionState == .connected else {
            return false
        }
        
        // Create a conversation item with the function result
        var functionDict: [String: Any] = ["name": functionName]
        
        if let error = error {
            functionDict["error"] = error
        } else {
            functionDict["result"] = result
        }
        
        let content: [String: Any] = [
            "type": "function_result",
            "function": functionDict
        ]
        
        let conversationItemEvent: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "assistant",
                "content": [content]
            ]
        ]
        
        // Then, create a response event to request a model response
        let responseEvent: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": config.modalities
            ]
        ]
        
        do {
            // Send conversation item event
            let conversationItemData = try JSONSerialization.data(withJSONObject: conversationItemEvent)
            if let conversationItemString = String(data: conversationItemData, encoding: .utf8) {
                try await websocket.send(conversationItemString)
            }
            
            // Send response event
            let responseData = try JSONSerialization.data(withJSONObject: responseEvent)
            if let responseString = String(data: responseData, encoding: .utf8) {
                try await websocket.send(responseString)
            }
            
            return true
        } catch {
            print("Error sending function result: \(error)")
            return false
        }
    }
    
    /// Send an assistant message to the Realtime API
    /// - Parameter content: The assistant message text
    /// - Returns: A boolean indicating success
    func sendAssistantMessage(content text: String) async -> Bool {
        guard let websocket = websocket, sessionState == .connected else {
            return false
        }
        
        // Create a conversation item event with the assistant message
        let conversationItemEvent: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "assistant",
                "content": [
                    [
                        "type": "text",
                        "text": text
                    ]
                ]
            ]
        ]
        
        do {
            // Add assistant message to the UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let assistantMessage = AgentMessage(
                    messageType: .assistantOutput,
                    sender: "Assistant",
                    recipient: "User",
                    content: text
                )
                self.messages.append(assistantMessage)
                
                // Notify delegate
                self.delegate?.realtimeSession(self, didReceiveMessage: assistantMessage)
            }
            
            // Send conversation item event
            let conversationItemData = try JSONSerialization.data(withJSONObject: conversationItemEvent)
            if let conversationItemString = String(data: conversationItemData, encoding: .utf8) {
                try await websocket.send(conversationItemString)
            }
            
            return true
        } catch {
            print("Error sending assistant message: \(error)")
            return false
        }
    }
    
    /// Disconnect from the OpenAI Realtime API
    func disconnect() {
        websocket?.close().whenComplete { [weak self] _ in
            self?.websocket = nil
            self?.eventLoopGroup?.shutdownGracefully { _ in
                self?.eventLoopGroup = nil
            }
            
            DispatchQueue.main.async {
                self?.sessionState = .disconnected
                self?.delegate?.realtimeSession(self!, didChangeState: .disconnected)
            }
        }
    }
    
    deinit {
        disconnect()
    }
    
    /// Set the user context for better AI responses
    /// - Parameter context: The context to set
    /// - Returns: Success indicator
    func setContext(_ context: String) async -> Bool {
        guard sessionState == .connected else {
            return false
        }
        
        // Format context as a system message
        let systemPrompt = """
        User project context:
        \(context)
        
        Use this context to provide more relevant and helpful responses.
        """
        
        // Send a session.update event with the system prompt as instructions
        let event: [String: Any] = [
            "type": "session.update",
            "session": [
                "instructions": systemPrompt
            ]
        ]
        
        do {
            try await sendEvent(event)
            return true
        } catch {
            print("Failed to set context: \(error)")
            return false
        }
    }
    
    /// Send an event to the server
    /// - Parameter event: The event to send
    /// - Throws: Error if sending the event fails
    private func sendEvent(_ event: [String: Any]) async throws {
        guard let websocket = websocket else {
            throw NSError(domain: "RealtimeSession", code: 1, userInfo: [NSLocalizedDescriptionKey: "No WebSocket connection"])
        }
        
        let eventData = try JSONSerialization.data(withJSONObject: event)
        if let eventString = String(data: eventData, encoding: .utf8) {
            try await websocket.send(eventString)
        } else {
            throw NSError(domain: "RealtimeSession", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize event"])
        }
    }
    
    /// Process a function call and notify handlers
    private func handleFunctionCallDelta(name: String, arguments: [String: Any], responseId: String) {
        // Format function call for display
        let functionCallContent: String
        if let argsData = try? JSONSerialization.data(withJSONObject: arguments),
           let argsString = String(data: argsData, encoding: .utf8) {
            functionCallContent = "Function Call: \(name)(\(argsString))"
            
            // Create a formatted message for display in the UI
            let formattedContent = "```\n\(functionCallContent)\n```"
            
            // Add to messages for display
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Add to messages
                let message = AgentMessage(
                    messageType: .assistantOutput,
                    sender: "Assistant",
                    recipient: "User",
                    content: formattedContent,
                    metadata: ["function_call": "true", "function_name": name]
                )
                
                self.messages.append(message)
                
                // Notify delegate
                self.delegate?.realtimeSession(self, didReceiveMessage: message)
                
                // Call registered handlers
                for handler in self.functionCallHandlers {
                    handler(name, arguments)
                }
            }
        }
    }
}
