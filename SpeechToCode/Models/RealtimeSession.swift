import Foundation
import NIO
import WebSocketKit
import NIOHTTP1
import AsyncHTTPClient
import NIOFoundationCompat

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
    @Published var state: SessionState = .disconnected
    @Published var messages: [AgentMessage] = []
    
    /// Session configuration
    private var apiKey: String
    private var modelId: String
    private var sessionId: String?
    private var websocket: WebSocket?
    private var eventLoopGroup: EventLoopGroup?
    
    // Use the external configuration
    private var config: RealtimeSessionConfig
    
    // Completion handlers for async events
    private var messageHandlers: [(AgentMessage) -> Void] = []
    private var functionCallHandlers: [(String, [String: Any]) -> Void] = []
    
    /// Initialize a new Realtime session
    /// - Parameters:
    ///   - apiKey: The OpenAI API key (if nil, will be retrieved from Config)
    ///   - modelId: The model ID to use (defaults to GPT-4o Realtime)
    ///   - config: Configuration options for the session
    init(apiKey: String? = nil, modelId: String = "gpt-4o-realtime-preview-2024-12-17", config: RealtimeSessionConfig = .default) {
        self.apiKey = apiKey ?? Config.OpenAI.apiKey
        self.modelId = modelId
        self.config = config
    }
    
    /// Connect to the OpenAI Realtime API
    /// - Returns: A boolean indicating success
    func connect() async -> Bool {
        guard state == .disconnected else {
            if state == .connected {
                return true // Already connected
            }
            return false
        }
        
        // Update state to connecting
        DispatchQueue.main.async { [self] in
            self.state = .connecting
        }
        
        do {
            // Create event loop group for the WebSocket
            eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            guard let eventLoopGroup = eventLoopGroup else {
                DispatchQueue.main.async {
                    self.state = .error("Failed to create event loop group")
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
                
                // Set up binary handler for audio data
                ws.onBinary { [weak self] _, buffer in
                    guard let self = self else { return }
                    self.handleBinaryData(buffer)
                }
                
                // Set up close handler
                ws.onClose.whenComplete { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success:
                        DispatchQueue.main.async {
                            self.state = .disconnected
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.state = .error("WebSocket closed with error: \(error.localizedDescription)")
                        }
                    }
                }
                
                // Update state to connected
                DispatchQueue.main.async {
                    self.state = .connected
                }
                
                // Configure the session
                self.configureSession()
            }
            
            // Wait for connection to complete or fail
            _ = try? await webSocketPromise.get()
            
            return true
        } catch {
            DispatchQueue.main.async { [self] in
                self.state = .error("Failed to connect: \(error.localizedDescription)")
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
                "temperature": config.temperature
            ]
        ]
        
        // Convert to JSON and send
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sessionUpdateEvent)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                websocket.send(jsonString)
            }
        } catch {
            print("Error creating session update: \(error)")
        }
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
                    
                case "response.audio.delta":
                    handleAudioDelta(json)
                    
                case "response.function_call.delta":
                    handleFunctionCallDelta(json)
                    
                case "response.done":
                    handleResponseDone(json)
                    
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
                    messageType: .userOutput,
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
           let delta = json["delta"] as? [String: Any],
           let text = delta["text"] as? String {
            
            // Update UI with text delta
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // If last message is from the same response, append the text
                if let lastIndex = self.messages.lastIndex(where: { $0.metadata["responseId"] == responseId }) {
                    let updatedContent = self.messages[lastIndex].content + text
                    let updatedMessage = AgentMessage(
                        messageType: .userOutput,
                        sender: "RealtimeSession",
                        recipient: "User",
                        content: updatedContent,
                        metadata: ["responseId": responseId]
                    )
                    self.messages[lastIndex] = updatedMessage
                } else {
                    // Create new message
                    let message = AgentMessage(
                        messageType: .userOutput,
                        sender: "RealtimeSession",
                        recipient: "User",
                        content: text,
                        metadata: ["responseId": responseId]
                    )
                    self.messages.append(message)
                }
            }
            
            // Notify handlers of new text
            for handler in messageHandlers {
                let message = AgentMessage(
                    messageType: .userOutput,
                    sender: "RealtimeSession",
                    recipient: "User",
                    content: text,
                    metadata: ["responseId": responseId, "isComplete": "false"]
                )
                handler(message)
            }
        }
    }
    
    /// Handle audio delta events
    /// - Parameter json: The event JSON
    private func handleAudioDelta(_ json: [String: Any]) {
        // Audio handling will be implemented in a future update
        // For now, we're focusing on text-based interaction
        if let responseId = json["response_id"] as? String {
            print("Audio delta received for response: \(responseId)")
        }
    }
    
    /// Handle binary data (usually audio)
    /// - Parameter buffer: The binary data buffer
    private func handleBinaryData(_ buffer: ByteBuffer) {
        // Audio handling will be implemented in a future update
        print("Binary data received: \(buffer.readableBytes) bytes")
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
                
                let message = AgentMessage(
                    messageType: .functionCall,
                    sender: "RealtimeSession",
                    recipient: "ConversationAgent",
                    content: functionCallContent,
                    metadata: [
                        "responseId": responseId,
                        "function": name
                    ]
                )
                self.messages.append(message)
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
    
    /// Send a user message to the Realtime API
    /// - Parameter text: The user message text
    /// - Returns: A boolean indicating success
    func sendUserMessage(_ text: String) async -> Bool {
        guard let websocket = websocket, state == .connected else {
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
                let userMessage = AgentMessage.userInput(text)
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
        guard let websocket = websocket, state == .connected else {
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
                let userMessage = AgentMessage.userInput(text)
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
        guard let websocket = websocket, state == .connected else {
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
    
    /// Disconnect from the Realtime API
    func disconnect() {
        websocket?.close().whenComplete { [weak self] _ in
            self?.websocket = nil
            self?.eventLoopGroup?.shutdownGracefully { _ in
                self?.eventLoopGroup = nil
            }
            
            DispatchQueue.main.async {
                self?.state = .disconnected
            }
        }
    }
    
    deinit {
        disconnect()
    }
}
