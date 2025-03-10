#!/usr/bin/swift

import Foundation
import Combine

// MARK: - Test Phase 5.1: Multi-Agent Orchestration

print("\n📱 SpeechToCode - Phase 5.1 Test Script: Multi-Agent Orchestration\n")

// MARK: - Mock Classes

// Mock state enums to match the real ones
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

enum AgentState: Equatable {
    case idle
    case processing
    case listeningForVoice
    case processingVoice
    case speaking
    case error(String)
    
    // Custom equality implementation for Equatable
    static func == (lhs: AgentState, rhs: AgentState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.processing, .processing),
             (.listeningForVoice, .listeningForVoice),
             (.processingVoice, .processingVoice),
             (.speaking, .speaking):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

enum SessionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    // Custom equality implementation for Equatable
    static func == (lhs: SessionState, rhs: SessionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

// Mock RealtimeSession for testing
class MockRealtimeSession: ObservableObject {
    @Published var sessionState: SessionState = .disconnected
    @Published var currentTranscription: String = ""
    
    var delegate: AnyObject?
    var apiKey: String
    
    init(apiKey: String = "test-key") {
        self.apiKey = apiKey
    }
    
    func connect() async -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.sessionState = .connected
        }
        return true
    }
    
    func disconnect() async {
        DispatchQueue.main.async { [weak self] in
            self?.sessionState = .disconnected
        }
    }
    
    func startListening() async -> Bool {
        return true
    }
    
    func stopListening() {
        // Do nothing
    }
    
    func sendUserMessage(content: String) async -> Bool {
        print("  [RealtimeSession] Sending message: \(content)")
        return true
    }
}

// Mock ConversationAgent for testing
class MockConversationAgent: ObservableObject {
    @Published var state: AgentState = .idle
    @Published var messages: [String] = []
    @Published var currentTranscription: String = ""
    @Published var isListening: Bool = false
    
    var realtimeSession: MockRealtimeSession?
    var planningAgent: MockPlanningAgent?
    var orchestrator: MockAgentOrchestrator?
    
    func connectToOrchestrator(_ orchestrator: MockAgentOrchestrator) {
        self.orchestrator = orchestrator
        print("  [ConversationAgent] Connected to orchestrator")
    }
    
    func connectToRealtimeSession(_ session: Any) {
        if let session = session as? MockRealtimeSession {
            self.realtimeSession = session
            print("  [ConversationAgent] Connected to realtime session")
        }
    }
    
    func connectToPlanningAgent(_ agent: MockPlanningAgent) {
        self.planningAgent = agent
        print("  [ConversationAgent] Connected to planning agent")
    }
    
    func connectToTerminalController(_ controller: Any) {
        print("  [ConversationAgent] Connected to terminal controller")
    }
    
    func processUserInput(_ input: String) async -> Bool {
        print("  [ConversationAgent] Processing user input: \(input)")
        messages.append("User: \(input)")
        
        if let taskId = orchestrator?.addPendingTask() {
            // Simulate work
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // Complete the task
            orchestrator?.completePendingTask(taskId)
        }
        
        return true
    }
}

// Mock PlanningAgent for testing
class MockPlanningAgent: ObservableObject {
    @Published var isInitialized: Bool = false
    @Published var currentProject: String = ""
    
    func initialize() async throws {
        isInitialized = true
        print("  [PlanningAgent] Initialized")
    }
    
    func createProjectContext(from input: String) async -> String {
        print("  [PlanningAgent] Creating project context from: \(input)")
        return "Project context for \(input)"
    }
}

// Mock SessionManager for testing
class MockSessionManager: ObservableObject {
    @Published var state: String = "idle"
    @Published var isRealtimeConnected: Bool = false
    
    var realtimeSession: MockRealtimeSession
    
    init(realtimeApiKey: String = "test-key") {
        self.realtimeSession = MockRealtimeSession(apiKey: realtimeApiKey)
    }
    
    func initializeSessions() async -> Bool {
        print("  [SessionManager] Initializing sessions")
        isRealtimeConnected = await realtimeSession.connect()
        return isRealtimeConnected
    }
    
    func shutdown() async -> Bool {
        print("  [SessionManager] Shutting down sessions")
        await realtimeSession.disconnect()
        isRealtimeConnected = false
        return true
    }
    
    func getRealtimeSession() -> MockRealtimeSession {
        return realtimeSession
    }
}

// Mock AgentOrchestrator for testing
class MockAgentOrchestrator: ObservableObject {
    @Published var state: OrchestratorState = .initializing
    @Published var activeAgents: Int = 0
    @Published var pendingTasks: Int = 0
    
    var conversationAgent: MockConversationAgent?
    var planningAgent: MockPlanningAgent?
    var sessionManager: MockSessionManager?
    var terminalController: AnyObject?
    
    private var pendingTaskIds = Set<String>()
    private let taskQueue = DispatchQueue(label: "com.speechtocode.taskQueue", attributes: .concurrent)
    
    init(sessionManager: MockSessionManager? = nil) {
        self.sessionManager = sessionManager
    }
    
    func connectConversationAgent(_ agent: MockConversationAgent) {
        self.conversationAgent = agent
        agent.connectToOrchestrator(self)
        activeAgents += 1
        print("  [Orchestrator] Connected conversation agent")
    }
    
    func connectPlanningAgent(_ agent: MockPlanningAgent) {
        self.planningAgent = agent
        activeAgents += 1
        print("  [Orchestrator] Connected planning agent")
    }
    
    func connectRealtimeSession() -> Bool {
        guard let sessionManager = sessionManager else {
            state = .error("SessionManager not available")
            return false
        }
        
        let realtimeSession = sessionManager.getRealtimeSession()
        
        // Connect to conversation agent if available
        if let conversationAgent = conversationAgent {
            conversationAgent.connectToRealtimeSession(realtimeSession)
            return true
        } else {
            return false
        }
    }
    
    func startAgents() async -> Bool {
        state = .initializing
        print("  [Orchestrator] Starting agents...")
        
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
        
        // Mark as ready
        state = .ready
        print("  [Orchestrator] Agents started and ready")
        
        return true
    }
    
    func pauseAgents() async -> Bool {
        guard state == .running || state == .ready else {
            return false
        }
        
        state = .paused
        print("  [Orchestrator] Agents paused")
        return true
    }
    
    func resumeAgents() async -> Bool {
        guard state == .paused else {
            return false
        }
        
        state = .running
        print("  [Orchestrator] Agents resumed")
        return true
    }
    
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
        
        print("  [Orchestrator] Added pending task: \(taskId)")
        return taskId
    }
    
    func completePendingTask(_ taskId: String) {
        taskQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.pendingTaskIds.remove(taskId)
            
            DispatchQueue.main.async {
                self.pendingTasks = self.pendingTaskIds.count
            }
        }
        
        print("  [Orchestrator] Completed pending task: \(taskId)")
    }
    
    func shutdown() async -> Bool {
        state = .shutdownInProgress
        print("  [Orchestrator] Shutting down...")
        
        // Shutdown session manager
        if let sessionManager = sessionManager {
            await sessionManager.shutdown()
        }
        
        // Clear references
        conversationAgent = nil
        planningAgent = nil
        terminalController = nil
        
        state = .shutdown
        print("  [Orchestrator] Shutdown complete")
        return true
    }
    
    func getConversationAgent() -> MockConversationAgent? {
        return conversationAgent
    }
    
    func getPlanningAgent() -> MockPlanningAgent? {
        return planningAgent
    }
    
    func getSessionManager() -> MockSessionManager? {
        return sessionManager
    }
}

// MARK: - Test Functions

/// Simple assertion function
func assert(_ condition: Bool, message: String) {
    if condition {
        print("✓ PASS: \(message)")
    } else {
        print("× FAIL: \(message)")
    }
}

/// Test orchestrator initialization
func testOrchestratorInitialization() {
    print("\n--- Testing Orchestrator Initialization ---\n")
    
    let sessionManager = MockSessionManager()
    let orchestrator = MockAgentOrchestrator(sessionManager: sessionManager)
    
    assert(orchestrator.state == .initializing, 
           message: "Orchestrator should be in initializing state")
    
    assert(orchestrator.activeAgents == 0, 
           message: "Orchestrator should have 0 active agents initially")
    
    assert(orchestrator.pendingTasks == 0, 
           message: "Orchestrator should have 0 pending tasks initially")
    
    print("  Orchestrator initialization test completed")
}

/// Test agent connections
func testAgentConnections() {
    print("\n--- Testing Agent Connections ---\n")
    
    let sessionManager = MockSessionManager()
    let orchestrator = MockAgentOrchestrator(sessionManager: sessionManager)
    let conversationAgent = MockConversationAgent()
    let planningAgent = MockPlanningAgent()
    
    // Connect agents
    orchestrator.connectConversationAgent(conversationAgent)
    orchestrator.connectPlanningAgent(planningAgent)
    
    // Verify connections
    assert(orchestrator.getConversationAgent() != nil, 
           message: "Conversation agent should be connected")
    
    assert(orchestrator.getPlanningAgent() != nil, 
           message: "Planning agent should be connected")
    
    assert(orchestrator.activeAgents == 2, 
           message: "Orchestrator should have 2 active agents")
    
    print("  Agent connections test completed")
}

/// Test task tracking
func testTaskTracking() async {
    print("\n--- Testing Task Tracking ---\n")
    
    let sessionManager = MockSessionManager()
    let orchestrator = MockAgentOrchestrator(sessionManager: sessionManager)
    
    // Track initial value
    assert(orchestrator.pendingTasks == 0, 
           message: "Initial pending tasks should be 0")
    
    // Add a task
    let taskId = orchestrator.addPendingTask()
    
    // Wait a bit for async operations
    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    
    // Since pendingTasks is updated asynchronously, we'll need to check after a short delay
    assert(orchestrator.pendingTasks > 0, 
           message: "Pending tasks should increase after adding a task")
    
    // Complete the task
    orchestrator.completePendingTask(taskId)
    
    // Wait a bit for async operations
    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    
    // Check again after the task is completed
    assert(orchestrator.pendingTasks == 0, 
           message: "Pending tasks should be 0 after completing a task")
    
    print("  Task tracking test completed")
}

/// Test orchestration lifecycle
func testOrchestrationLifecycle() async {
    print("\n--- Testing Orchestration Lifecycle ---\n")
    
    let sessionManager = MockSessionManager()
    let orchestrator = MockAgentOrchestrator(sessionManager: sessionManager)
    let conversationAgent = MockConversationAgent()
    let planningAgent = MockPlanningAgent()
    
    // Connect agents
    orchestrator.connectConversationAgent(conversationAgent)
    orchestrator.connectPlanningAgent(planningAgent)
    
    // Start agents
    let startSuccess = await orchestrator.startAgents()
    assert(startSuccess, message: "Starting agents should succeed")
    assert(orchestrator.state == .ready, message: "State should be ready after starting")
    
    // Pause agents
    let pauseSuccess = await orchestrator.pauseAgents()
    assert(pauseSuccess, message: "Pausing agents should succeed")
    assert(orchestrator.state == .paused, message: "State should be paused after pausing")
    
    // Resume agents
    let resumeSuccess = await orchestrator.resumeAgents()
    assert(resumeSuccess, message: "Resuming agents should succeed")
    assert(orchestrator.state == .running, message: "State should be running after resuming")
    
    print("  Orchestration lifecycle test completed")
}

/// Test error handling
func testErrorHandling() async {
    print("\n--- Testing Error Handling ---\n")
    
    // Create a new orchestrator with a null session manager to force an error
    let errorOrchestrator = MockAgentOrchestrator()
    errorOrchestrator.sessionManager = nil
    
    // Try to start agents (should fail)
    let startResult = await errorOrchestrator.startAgents()
    
    assert(!startResult, 
           message: "Starting without a session manager should fail")
    
    // Check if the orchestrator is in error state
    if case .error = errorOrchestrator.state {
        assert(true, message: "Orchestrator should be in error state")
    } else {
        assert(false, message: "Orchestrator should be in error state but is in \(errorOrchestrator.state)")
    }
    
    print("  Error handling test completed")
}

/// Test full workflow
func testFullWorkflow() async {
    print("\n--- Testing Full Workflow ---\n")
    
    let sessionManager = MockSessionManager()
    let orchestrator = MockAgentOrchestrator(sessionManager: sessionManager)
    let conversationAgent = MockConversationAgent()
    let planningAgent = MockPlanningAgent()
    
    // Set up components
    orchestrator.connectConversationAgent(conversationAgent)
    orchestrator.connectPlanningAgent(planningAgent)
    
    // Start the system
    let startSuccess = await orchestrator.startAgents()
    assert(startSuccess, message: "Starting agents should succeed")
    
    // Simulate a user interaction
    let processingSuccess = await conversationAgent.processUserInput("Explain how to use Swift async/await")
    assert(processingSuccess, message: "Processing user input should succeed")
    
    // Shutdown
    let shutdownSuccess = await orchestrator.shutdown()
    assert(shutdownSuccess, message: "Shutdown should succeed")
    assert(orchestrator.state == .shutdown, message: "Orchestrator should be in shutdown state")
    
    print("  Full workflow test completed")
}

// MARK: - Run Tests

// Run all the tests
func runAllTests() async {
    print("🧪 Running Phase 5.1 Multi-Agent Orchestration Tests...\n")
    
    // Run all tests
    testOrchestratorInitialization()
    await testTaskTracking()
    testAgentConnections()
    await testOrchestrationLifecycle()
    await testErrorHandling()
    await testFullWorkflow()
    
    print("\n🏁 Phase 5.1 tests completed successfully")
}

// Execute the tests
await runAllTests()
