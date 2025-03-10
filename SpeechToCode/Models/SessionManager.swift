import Foundation
import Combine

/// Manages API sessions for the SpeechToCode application
@available(macOS 10.15, *)
class SessionManager: ObservableObject {
    
    /// Current state of the session manager
    enum SessionManagerState: Equatable {
        case idle
        case initializing
        case active
        case reconnecting
        case shutdownInProgress
        case shutdown
        case error(String)
        
        // Implement Equatable for SessionManagerState with associated values
        static func == (lhs: SessionManagerState, rhs: SessionManagerState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.initializing, .initializing),
                 (.active, .active),
                 (.reconnecting, .reconnecting),
                 (.shutdownInProgress, .shutdownInProgress),
                 (.shutdown, .shutdown):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    /// Published properties for SwiftUI integration
    @Published var state: SessionManagerState = .idle
    @Published var isRealtimeConnected: Bool = false
    @Published var isClaudeConnected: Bool = false
    @Published var reconnectionAttempts: Int = 0
    
    /// Session instances
    private var realtimeSession: RealtimeSession?
    private var claudeSession: Any? // Using Any since we don't have the exact type yet
    
    /// Configuration
    private var realtimeApiKey: String?
    private var claudeApiKey: String?
    private var maxReconnectionAttempts: Int = 3
    private var autoReconnect: Bool = true
    
    /// Resource cleanup
    private var cancellables = Set<AnyCancellable>()
    
    /// Event handlers
    private var onRealtimeConnected: (() -> Void)?
    private var onRealtimeDisconnected: (() -> Void)?
    private var onClaudeConnected: (() -> Void)?
    private var onClaudeDisconnected: (() -> Void)?
    
    /// Initialize a new Session Manager
    /// - Parameters:
    ///   - realtimeApiKey: Optional API key for Realtime API (will use Config if nil)
    ///   - claudeApiKey: Optional API key for Claude API (will use Config if nil)
    init(realtimeApiKey: String? = nil, claudeApiKey: String? = nil) {
        self.realtimeApiKey = realtimeApiKey ?? Config.OpenAI.apiKey
        // Using default empty string for Claude API key until Config.Claude is implemented
        self.claudeApiKey = claudeApiKey ?? ""
    }
    
    /// Configure the Realtime session
    /// - Parameter config: Configuration options for the session
    /// - Returns: The configured session
    func configureRealtimeSession(config: RealtimeSessionConfig = .default) -> RealtimeSession {
        let session = RealtimeSession(apiKey: realtimeApiKey, config: config)
        
        // Set up observers for session state
        session.$sessionState
            .sink { [weak self] sessionState in
                guard let self = self else { return }
                
                switch sessionState {
                case .connected:
                    self.isRealtimeConnected = true
                    self.onRealtimeConnected?()
                case .disconnected:
                    self.isRealtimeConnected = false
                    self.onRealtimeDisconnected?()
                    if self.autoReconnect && self.state == .active {
                        Task {
                            await self.attemptRealtimeReconnection()
                        }
                    }
                case .error:
                    self.isRealtimeConnected = false
                    self.onRealtimeDisconnected?()
                    if self.autoReconnect && self.state == .active {
                        Task {
                            await self.attemptRealtimeReconnection()
                        }
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        self.realtimeSession = session
        return session
    }
    
    /// Initialize and connect all sessions
    /// - Returns: Boolean indicating success
    @discardableResult
    func initializeSessions() async -> Bool {
        state = .initializing
        
        // Ensure we have a realtime session
        if realtimeSession == nil {
            _ = configureRealtimeSession()
        }
        
        // Connect to Realtime API
        guard let realtimeSession = realtimeSession else {
            state = .error("Failed to create Realtime session")
            return false
        }
        
        let realtimeConnected = await realtimeSession.connect()
        if !realtimeConnected {
            state = .error("Failed to connect to Realtime API")
            return false
        }
        
        // Initialize Claude session (if Claude helper is ever implemented)
        // This is a placeholder for future Claude integration
        
        state = .active
        return true
    }
    
    /// Attempt to reconnect to the Realtime API
    /// - Returns: Boolean indicating success
    private func attemptRealtimeReconnection() async -> Bool {
        guard let realtimeSession = realtimeSession else {
            return false
        }
        
        if reconnectionAttempts >= maxReconnectionAttempts {
            state = .error("Failed to reconnect after \(maxReconnectionAttempts) attempts")
            return false
        }
        
        reconnectionAttempts += 1
        state = .reconnecting
        
        let success = await realtimeSession.connect()
        
        if success {
            reconnectionAttempts = 0
            state = .active
            return true
        } else {
            // Try again after a delay
            if reconnectionAttempts < maxReconnectionAttempts {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                return await attemptRealtimeReconnection()
            } else {
                state = .error("Failed to reconnect after \(maxReconnectionAttempts) attempts")
                return false
            }
        }
    }
    
    /// Set a callback for when the Realtime API connects
    /// - Parameter handler: The handler to call
    func onRealtimeConnected(_ handler: @escaping () -> Void) {
        onRealtimeConnected = handler
    }
    
    /// Set a callback for when the Realtime API disconnects
    /// - Parameter handler: The handler to call
    func onRealtimeDisconnected(_ handler: @escaping () -> Void) {
        onRealtimeDisconnected = handler
    }
    
    /// Set a callback for when the Claude API connects
    /// - Parameter handler: The handler to call
    func onClaudeConnected(_ handler: @escaping () -> Void) {
        onClaudeConnected = handler
    }
    
    /// Set a callback for when the Claude API disconnects
    /// - Parameter handler: The handler to call
    func onClaudeDisconnected(_ handler: @escaping () -> Void) {
        onClaudeDisconnected = handler
    }
    
    /// Shutdown all sessions
    /// - Returns: Boolean indicating success
    @discardableResult
    func shutdown() async -> Bool {
        state = .shutdownInProgress
        
        // Disconnect from Realtime API
        if let realtimeSession = realtimeSession, isRealtimeConnected {
            realtimeSession.disconnect()
        }
        
        // Clear Claude session if necessary
        // This is a placeholder for future Claude integration
        
        // Clear cancellables to stop observations
        cancellables.removeAll()
        
        state = .shutdown
        return true
    }
    
    /// Get the current Realtime session
    /// - Returns: The configured Realtime session or nil if not available
    func getRealtimeSession() -> RealtimeSession? {
        return realtimeSession
    }
}
