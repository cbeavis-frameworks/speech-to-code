import Foundation
import Combine

/// Orchestrates multiple agents, managing their state and lifecycle
@available(macOS 10.15, *)
class AgentOrchestrator: ObservableObject, @unchecked Sendable {
    /// State of the orchestrator
    enum OrchestratorState {
        case initializing
        case ready
        case running
        case paused
        case shutdownInProgress
        case shutdown
        case error(String)
    }
    
    /// Types of agents that can be orchestrated
    enum AgentType: String, CaseIterable {
        case conversation = "Conversation"
        case planning = "Planning"
        case terminal = "Terminal"
        case context = "Context"
    }
    
    /// The current state of the orchestrator
    @Published var state: OrchestratorState = .initializing
    
    /// The number of active agents
    @Published var activeAgents: Int = 0
    
    /// The number of pending tasks
    @Published var pendingTasks: Int = 0
    
    /// Map of pending tasks with their IDs
    private var pendingTasksMap: [String: Date] = [:]
    
    /// Conversation agent
    var conversationAgent: ConversationAgent?
    
    /// Planning agent
    var planningAgent: PlanningAgent?
    
    /// Context manager
    var contextManager: ContextManager?
    
    /// Terminal controller
    var terminalController: TerminalController?
    
    /// Workflow manager
    var workflowManager: WorkflowManager?
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize the orchestrator
    init() {
        // Start in initializing state
        state = .initializing
    }
    
    /// Initialize all agents
    /// - Returns: Success indicator
    @discardableResult
    func initializeAllAgents() async -> Bool {
        // Create and initialize the planning agent
        let planningAgent = PlanningAgent()
        self.planningAgent = planningAgent
        activeAgents += 1
        
        // Create and initialize the terminal controller
        let terminalController = TerminalController()
        self.terminalController = terminalController
        
        // Create and initialize the conversation agent
        let conversationAgent = ConversationAgent()
        conversationAgent.setPlanningAgent(planningAgent)
        conversationAgent.setTerminalController(terminalController)
        self.conversationAgent = conversationAgent
        activeAgents += 1
        
        // Create and initialize the context manager
        let contextManager = ContextManager()
        self.contextManager = contextManager
        
        // Create and initialize the workflow manager
        let workflowManager = WorkflowManager()
        workflowManager.connectToOrchestrator(self)
        self.workflowManager = workflowManager
        
        // Connect agents to each other
        connectAgents()
        
        // Initialize context manager
        if let contextManager = self.contextManager {
            _ = await contextManager.initialize()
        }
        
        activeAgents += 1
        
        // Set state to ready
        DispatchQueue.main.async { [weak self] in
            self?.state = .ready
        }
        
        return true
    }
    
    /// Connect agents to each other
    func connectAgents() {
        guard let conversationAgent = conversationAgent,
              let planningAgent = self.planningAgent,
              let contextManager = contextManager else {
            return
        }
        
        // Connect conversation agent to planning agent
        conversationAgent.setPlanningAgent(planningAgent)
        
        // Connect planning agent to context manager
        contextManager.connectPlanningAgent(planningAgent)
        
        // Connect conversation agent to context manager
        contextManager.connectConversationAgent(conversationAgent)
        
        // Connect orchestrator to context manager
        contextManager.connectOrchestrator(self)
        
        // Connect workflow manager to orchestrator
        if let workflowManager = workflowManager {
            workflowManager.connectToOrchestrator(self)
        }
    }
    
    /// Get the conversation agent
    /// - Returns: The conversation agent
    func getConversationAgent() -> ConversationAgent? {
        return conversationAgent
    }
    
    /// Get the planning agent
    /// - Returns: The planning agent
    func getPlanningAgent() -> PlanningAgent? {
        return planningAgent
    }
    
    /// Get the context manager
    /// - Returns: The context manager
    func getContextManager() -> ContextManager? {
        return contextManager
    }
    
    /// Get the workflow manager
    /// - Returns: The workflow manager
    func getWorkflowManager() -> WorkflowManager? {
        return workflowManager
    }
    
    /// Connect to a Conversation Agent
    /// - Parameter agent: The conversation agent to connect
    func connectConversationAgent(_ agent: ConversationAgent) {
        self.conversationAgent = agent
        
        // Also connect the conversation agent to the context manager
        if let contextManager = contextManager {
            contextManager.connectConversationAgent(agent)
        }
    }
    
    /// Connect to a Planning Agent
    /// - Parameter agent: The planning agent to connect
    func connectPlanningAgent(_ agent: PlanningAgent) {
        self.planningAgent = agent
        
        // Also connect the planning agent to the context manager
        if let contextManager = contextManager {
            contextManager.connectPlanningAgent(agent)
        }
    }
    
    /// Connect to a Context Manager
    /// - Parameter manager: The context manager to connect
    func connectContextManager(_ manager: ContextManager) {
        self.contextManager = manager
        
        // Also connect the orchestrator to the context manager
        manager.connectOrchestrator(self)
        
        // Connect any existing agents to the context manager
        if let conversationAgent = conversationAgent {
            manager.connectConversationAgent(conversationAgent)
        }
        
        if let planningAgent = planningAgent {
            manager.connectPlanningAgent(planningAgent)
        }
    }
    
    /// Connect to a Workflow Manager
    /// - Parameter manager: The workflow manager to connect
    func connectWorkflowManager(_ manager: WorkflowManager) {
        self.workflowManager = manager
        
        // Also connect the workflow manager to the orchestrator
        manager.connectToOrchestrator(self)
    }
    
    /// Start processing with all agents
    func startProcessing() {
        // Set state to running
        state = .running
        
        // Start conversation agent
        Task {
            _ = await conversationAgent?.processUserInput("start")
        }
    }
    
    /// Pause all processing
    func pauseProcessing() {
        // Set state to paused
        state = .paused
        
        // Pause conversation agent (using existing method)
        if let conversationAgent = conversationAgent {
            conversationAgent.state = .idle
        }
    }
    
    /// Resume processing after pause
    func resumeProcessing() {
        // Set state to running
        state = .running
        
        // Resume conversation agent (using existing method)
        if let conversationAgent = conversationAgent {
            conversationAgent.state = .idle  // Reset state to idle so it can process new inputs
        }
    }
    
    /// Shutdown all agents
    func shutdown() async {
        // Set state to shutdown in progress
        state = .shutdownInProgress
        
        // Save context before shutdown
        await contextManager?.refreshContextForAgents()
        
        // Shut down conversation agent
        if let conversationAgent = conversationAgent {
            conversationAgent.state = .idle
        }
        
        // Set state to shutdown
        state = .shutdown
    }
    
    /// Add a pending task and return its ID
    /// - Returns: Task ID
    func addPendingTask() -> String {
        let taskId = UUID().uuidString
        pendingTasksMap[taskId] = Date()
        
        DispatchQueue.main.async { [weak self] in
            self?.pendingTasks += 1
        }
        
        return taskId
    }
    
    /// Complete a pending task
    /// - Parameter taskId: The task ID
    func completePendingTask(_ taskId: String) {
        if pendingTasksMap.removeValue(forKey: taskId) != nil {
            DispatchQueue.main.async { [weak self] in
                self?.pendingTasks -= 1
            }
        }
    }
    
    /// Refresh contexts for all agents
    /// - Returns: Success indicator
    @discardableResult
    func refreshAllContexts() async -> Bool {
        guard let contextManager = contextManager else {
            return false
        }
        
        return await contextManager.refreshContextForAgents()
    }
}
