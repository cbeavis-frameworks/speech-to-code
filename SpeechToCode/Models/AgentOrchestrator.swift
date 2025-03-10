import Foundation
import Combine
import AppKit

/// Orchestrates multiple agents in the SpeechToCode system
@available(macOS 10.15, *)
class AgentOrchestrator: ObservableObject {
    
    /// State of the orchestrator
    enum OrchestratorState: Equatable {
        case initializing
        case ready
        case running
        case paused
        case shutdownInProgress
        case shutdown
        case error(String)
        
        // Custom equality implementation for Equatable
        static func == (lhs: OrchestratorState, rhs: OrchestratorState) -> Bool {
            switch (lhs, rhs) {
            case (.initializing, .initializing),
                 (.ready, .ready),
                 (.running, .running),
                 (.paused, .paused),
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
    @Published var state: OrchestratorState = .initializing
    @Published var activeAgents: Int = 0
    @Published var pendingTasks: Int = 0
    
    /// Agent references
    private var conversationAgent: ConversationAgent?
    private var planningAgent: PlanningAgent?
    private var sessionManager: SessionManager?
    private var terminalController: Any? // Using Any since we don't have the exact type yet
    
    /// Task tracking
    private var pendingTaskIds = Set<String>()
    private let taskQueue = DispatchQueue(label: "com.speechtocode.taskQueue", attributes: .concurrent)
    
    /// Cleanup resources
    private var cancellables = Set<AnyCancellable>()
    
    /// Initialize a new Agent Orchestrator
    /// - Parameter sessionManager: Optional session manager (will create one if nil)
    init(sessionManager: SessionManager? = nil) {
        self.sessionManager = sessionManager ?? SessionManager()
        
        // Set initial state
        state = .initializing
        
        // Register for app termination to ensure clean shutdown
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    /// Handle application termination
    @objc private func applicationWillTerminate() {
        Task {
            await shutdown()
        }
    }
    
    /// Connect to a Conversation Agent
    /// - Parameter agent: The conversation agent to connect
    func connectConversationAgent(_ agent: ConversationAgent) {
        self.conversationAgent = agent
        agent.connectToOrchestrator(self)
        
        // Set up observers for agent state changes
        // Using standard publisher pattern instead of keypath
        agent.$state
            .sink { [weak self] (state: ConversationAgent.AgentState) in
                guard let self = self else { return }
                
                // Handle agent state changes
                switch state {
                case .error(let message):
                    self.handleAgentError(agent: "ConversationAgent", message: message)
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    /// Connect to a Planning Agent
    /// - Parameter agent: The planning agent to connect
    func connectPlanningAgent(_ agent: PlanningAgent) {
        self.planningAgent = agent
        
        // Set up observers for agent state changes if applicable
    }
    
    /// Connect to a Realtime Session through the Session Manager
    /// - Returns: Boolean indicating success
    func connectRealtimeSession() -> Bool {
        guard let sessionManager = sessionManager else {
            state = .error("SessionManager not available")
            return false
        }
        
        if let realtimeSession = sessionManager.getRealtimeSession() {
            // Connect to conversation agent if available
            if let conversationAgent = conversationAgent {
                conversationAgent.connectToRealtimeSession(realtimeSession)
            }
            
            return true
        } else {
            state = .error("Realtime session not available")
            return false
        }
    }
    
    /// Connect to a Terminal Controller
    /// - Parameter controller: The terminal controller to connect
    func connectTerminalController(_ controller: Any) {
        self.terminalController = controller
        
        // Connect to conversation agent if available
        if let conversationAgent = conversationAgent {
            conversationAgent.connectToTerminalController(controller)
        }
    }
    
    /// Start the orchestrator and all connected agents
    /// - Returns: Boolean indicating success
    @discardableResult
    func startAgents() async -> Bool {
        state = .initializing
        
        // Initialize session manager if not already done
        guard let sessionManager = sessionManager else {
            state = .error("SessionManager not available")
            return false
        }
        
        // Initialize sessions
        let sessionsInitialized = await sessionManager.initializeSessions()
        if !sessionsInitialized {
            state = .error("Failed to initialize sessions")
            return false
        }
        
        // Connect agents to sessions
        _ = connectRealtimeSession()
        
        // Connect planning agent to conversation agent if both available
        if let planningAgent = planningAgent, let conversationAgent = conversationAgent {
            conversationAgent.connectToPlanningAgent(planningAgent)
        }
        
        // Update agent count
        updateActiveAgentCount()
        
        // Mark as ready
        state = .ready
        
        return true
    }
    
    /// Resume agents after pausing
    /// - Returns: Boolean indicating success
    @discardableResult
    func resumeAgents() async -> Bool {
        guard state == .paused else {
            return false
        }
        
        state = .running
        return true
    }
    
    /// Pause all agents
    /// - Returns: Boolean indicating success
    @discardableResult
    func pauseAgents() async -> Bool {
        guard state == .running || state == .ready else {
            return false
        }
        
        state = .paused
        return true
    }
    
    /// Shutdown all agents and cleanup resources
    /// - Returns: Boolean indicating success
    @discardableResult
    func shutdown() async -> Bool {
        state = .shutdownInProgress
        
        // Wait for pending tasks to complete
        await waitForPendingTasks(timeout: 5.0)
        
        // Shutdown session manager
        if let sessionManager = sessionManager {
            await sessionManager.shutdown()
        }
        
        // Clear observers
        cancellables.removeAll()
        
        // Reset references
        conversationAgent = nil
        planningAgent = nil
        terminalController = nil
        
        state = .shutdown
        return true
    }
    
    /// Handle an error from an agent
    /// - Parameters:
    ///   - agent: Name of the agent reporting the error
    ///   - message: Error message
    private func handleAgentError(agent: String, message: String) {
        // Log the error
        print("⚠️ \(agent) error: \(message)")
        
        // Update state if this is a critical error
        // For now, we're treating all agent errors as non-critical
        // state = .error("Agent error: \(message)")
    }
    
    /// Update the count of active agents
    private func updateActiveAgentCount() {
        var count = 0
        
        if conversationAgent != nil { count += 1 }
        if planningAgent != nil { count += 1 }
        
        DispatchQueue.main.async {
            self.activeAgents = count
        }
    }
    
    /// Add a pending task and get its ID
    /// - Returns: The task ID
    @discardableResult
    func addPendingTask() -> String {
        let taskId = UUID().uuidString
        
        taskQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.pendingTaskIds.insert(taskId)
            
            DispatchQueue.main.async {
                self.pendingTasks = self.pendingTaskIds.count
            }
        }
        
        return taskId
    }
    
    /// Mark a pending task as completed
    /// - Parameter taskId: The task ID to complete
    func completePendingTask(_ taskId: String) {
        taskQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.pendingTaskIds.remove(taskId)
            
            DispatchQueue.main.async {
                self.pendingTasks = self.pendingTaskIds.count
            }
        }
    }
    
    /// Wait for all pending tasks to complete
    /// - Parameter timeout: Maximum time to wait in seconds
    /// - Returns: Boolean indicating if all tasks completed
    @discardableResult
    func waitForPendingTasks(timeout: TimeInterval) async -> Bool {
        let startTime = Date()
        
        while !pendingTaskIds.isEmpty {
            // Check if we've exceeded the timeout
            if Date().timeIntervalSince(startTime) > timeout {
                return false
            }
            
            // Wait a bit
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        return true
    }
    
    /// Get the conversation agent
    /// - Returns: The connected conversation agent, if any
    func getConversationAgent() -> ConversationAgent? {
        return conversationAgent
    }
    
    /// Get the planning agent
    /// - Returns: The connected planning agent, if any
    func getPlanningAgent() -> PlanningAgent? {
        return planningAgent
    }
    
    /// Get the session manager
    /// - Returns: The session manager, if any
    func getSessionManager() -> SessionManager? {
        return sessionManager
    }
}
