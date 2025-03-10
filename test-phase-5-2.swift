#!/usr/bin/swift

import Foundation

// MARK: - Test Phase 5.2: Context Management

print("\n📱 SpeechToCode - Phase 5.2 Test Script: Context Management\n")

// MARK: - Mock Classes

// Mock ContextStorageProtocol for testing
class MockContextStorage: ContextManager.ContextStorageProtocol {
    var contexts: [ContextManager.ContextType: String] = [:]
    
    func saveContext(_ context: String, type: ContextManager.ContextType) throws {
        contexts[type] = context
        print("  [Storage] Saved context for type: \(type.rawValue)")
    }
    
    func loadContext(type: ContextManager.ContextType) throws -> String {
        return contexts[type] ?? ""
    }
    
    func listAvailableContextTypes() throws -> [ContextManager.ContextType] {
        return Array(contexts.keys)
    }
    
    func deleteContext(type: ContextManager.ContextType) throws {
        contexts.removeValue(forKey: type)
        print("  [Storage] Deleted context for type: \(type.rawValue)")
    }
}

// Mock PlanningAgent
class MockPlanningAgent {
    var projectContext: String = "This is a mock project context for testing."
    var isConnectedToContextManager = false
    
    func getProjectContext() -> String? {
        print("  [PlanningAgent] Providing project context")
        return projectContext
    }
    
    func connectToContextManager(_ manager: ContextManager) {
        isConnectedToContextManager = true
        print("  [PlanningAgent] Connected to Context Manager")
    }
}

// Mock ConversationAgent
class MockConversationAgent {
    var messages: [String] = [
        "User: Hello",
        "Assistant: Hi there! How can I help you?",
        "User: Can you help me with my project?",
        "Assistant: Of course! What are you working on?"
    ]
    var isConnectedToContextManager = false
    
    func generateConversationSummary() async -> String {
        print("  [ConversationAgent] Generating conversation summary")
        var summary = "# Conversation History\n\n"
        for message in messages {
            summary += message + "\n\n"
        }
        return summary
    }
    
    func connectToContextManager(_ manager: ContextManager) {
        isConnectedToContextManager = true
        print("  [ConversationAgent] Connected to Context Manager")
    }
}

// Mock AgentOrchestrator
class MockAgentOrchestrator {
    var pendingTasks: Int = 0
    var activeAgents: Int = 2
    var state: String = "ready"
    
    func addPendingTask() -> String {
        pendingTasks += 1
        let taskId = "task-\(UUID().uuidString.prefix(8))"
        print("  [Orchestrator] Added pending task: \(taskId)")
        return taskId
    }
    
    func completePendingTask(_ taskId: String) {
        pendingTasks -= 1
        print("  [Orchestrator] Completed task: \(taskId)")
    }
}

// MARK: - ContextManager Class (Simplified Version for Testing)

@available(macOS 10.15, *)
class ContextManager {
    var projectContext: String = ""
    var contextSummaries: [ContextType: String] = [:]
    var isInitialized: Bool = false
    var isRefreshing: Bool = false
    
    enum ContextType: String, Codable {
        case project
        case conversation
        case codeStructure
        case taskStatus
        case systemStatus
        case userPreferences
    }
    
    private var planningAgent: MockPlanningAgent?
    private var conversationAgent: MockConversationAgent?
    private var orchestrator: MockAgentOrchestrator?
    private var contextStorage: ContextStorageProtocol
    
    protocol ContextStorageProtocol {
        func saveContext(_ context: String, type: ContextType) throws
        func loadContext(type: ContextType) throws -> String
        func listAvailableContextTypes() throws -> [ContextType]
        func deleteContext(type: ContextType) throws
    }
    
    init(storage: ContextStorageProtocol) {
        self.contextStorage = storage
    }
    
    func connectPlanningAgent(_ agent: MockPlanningAgent) {
        self.planningAgent = agent
        agent.connectToContextManager(self)
    }
    
    func connectConversationAgent(_ agent: MockConversationAgent) {
        self.conversationAgent = agent
        agent.connectToContextManager(self)
    }
    
    func connectOrchestrator(_ orchestrator: MockAgentOrchestrator) {
        self.orchestrator = orchestrator
    }
    
    func initialize() async -> Bool {
        print("  [ContextManager] Initializing")
        do {
            try loadContextFromStorage()
            isInitialized = true
            return true
        } catch {
            print("  [ContextManager] Error initializing: \(error)")
            isInitialized = false
            return false
        }
    }
    
    private func loadContextFromStorage() throws {
        let availableTypes = try contextStorage.listAvailableContextTypes()
        
        for type in availableTypes {
            let context = try contextStorage.loadContext(type: type)
            if type == .project {
                projectContext = context
            } else {
                contextSummaries[type] = context
            }
        }
        print("  [ContextManager] Loaded \(availableTypes.count) context types from storage")
    }
    
    func updateProjectContext(_ context: String) -> Bool {
        projectContext = context
        do {
            try contextStorage.saveContext(context, type: .project)
            print("  [ContextManager] Updated project context")
            return true
        } catch {
            print("  [ContextManager] Error updating project context: \(error)")
            return false
        }
    }
    
    func updateContextSummary(_ summary: String, type: ContextType) -> Bool {
        if type == .project {
            return updateProjectContext(summary)
        }
        
        contextSummaries[type] = summary
        do {
            try contextStorage.saveContext(summary, type: type)
            print("  [ContextManager] Updated \(type.rawValue) context")
            return true
        } catch {
            print("  [ContextManager] Error updating \(type.rawValue) context: \(error)")
            return false
        }
    }
    
    func getContextSummary(type: ContextType) -> String {
        if type == .project {
            return projectContext
        }
        return contextSummaries[type] ?? ""
    }
    
    func getCombinedContext(types: [ContextType]) -> String {
        var combined = ""
        
        for type in types {
            let context = getContextSummary(type: type)
            if !context.isEmpty {
                combined += "### \(type.rawValue.capitalized) Context\n\(context)\n\n"
            }
        }
        
        return combined
    }
    
    func refreshContextForAgents() async -> Bool {
        guard !isRefreshing, isInitialized else {
            print("  [ContextManager] Cannot refresh: isRefreshing=\(isRefreshing), isInitialized=\(isInitialized)")
            return false
        }
        
        isRefreshing = true
        print("  [ContextManager] Starting context refresh")
        
        let taskId = orchestrator?.addPendingTask()
        
        if let planningAgent = planningAgent {
            if let context = planningAgent.getProjectContext() {
                updateProjectContext(context)
            }
        }
        
        if let conversationAgent = conversationAgent {
            let conversationSummary = await conversationAgent.generateConversationSummary()
            updateContextSummary(conversationSummary, type: .conversation)
        }
        
        if let taskId = taskId {
            orchestrator?.completePendingTask(taskId)
        }
        
        isRefreshing = false
        print("  [ContextManager] Finished context refresh")
        return true
    }
    
    func deleteContext(type: ContextType) -> Bool {
        do {
            try contextStorage.deleteContext(type: type)
            if type == .project {
                projectContext = ""
            } else {
                contextSummaries.removeValue(forKey: type)
            }
            print("  [ContextManager] Deleted \(type.rawValue) context")
            return true
        } catch {
            print("  [ContextManager] Error deleting context: \(error)")
            return false
        }
    }
}

// MARK: - Test Functions

@available(macOS 10.15, *)
func testContextStorage() async -> Bool {
    print("\n--- Testing Context Storage ---\n")
    
    let storage = MockContextStorage()
    let contextManager = ContextManager(storage: storage)
    
    // Test initialization
    let initialized = await contextManager.initialize()
    print("  Initialization successful: \(initialized)")
    
    // Test updating project context
    let projectContext = "This is a test project context with important information."
    let projectUpdated = contextManager.updateProjectContext(projectContext)
    print("  Project context updated: \(projectUpdated)")
    
    // Test updating conversation context
    let conversationContext = "# Conversation History\nUser: Hello\nAssistant: Hi there!"
    let conversationUpdated = contextManager.updateContextSummary(conversationContext, type: .conversation)
    print("  Conversation context updated: \(conversationUpdated)")
    
    // Test retrieving contexts
    let retrievedProject = contextManager.getContextSummary(type: .project)
    let projectMatches = retrievedProject == projectContext
    print("  Retrieved project context matches: \(projectMatches)")
    
    let retrievedConversation = contextManager.getContextSummary(type: .conversation)
    let conversationMatches = retrievedConversation == conversationContext
    print("  Retrieved conversation context matches: \(conversationMatches)")
    
    // Test combined context
    let combined = contextManager.getCombinedContext(types: [.project, .conversation])
    print("  Combined context length: \(combined.count) characters")
    
    // Test deleting context
    let deleted = contextManager.deleteContext(type: .conversation)
    print("  Conversation context deleted: \(deleted)")
    
    let deletedVerification = contextManager.getContextSummary(type: .conversation).isEmpty
    print("  Verification that context was deleted: \(deletedVerification)")
    
    return initialized && projectUpdated && conversationUpdated && 
           projectMatches && conversationMatches && deleted && deletedVerification
}

@available(macOS 10.15, *)
func testAgentIntegration() async -> Bool {
    print("\n--- Testing Agent Integration ---\n")
    
    let storage = MockContextStorage()
    let contextManager = ContextManager(storage: storage)
    let planningAgent = MockPlanningAgent()
    let conversationAgent = MockConversationAgent()
    let orchestrator = MockAgentOrchestrator()
    
    // Connect agents to context manager
    contextManager.connectPlanningAgent(planningAgent)
    contextManager.connectConversationAgent(conversationAgent)
    contextManager.connectOrchestrator(orchestrator)
    
    // Initialize the context manager
    let initialized = await contextManager.initialize()
    print("  Context manager initialized: \(initialized)")
    
    // Verify connections
    print("  Planning agent connected: \(planningAgent.isConnectedToContextManager)")
    print("  Conversation agent connected: \(conversationAgent.isConnectedToContextManager)")
    
    // Test context refresh
    let refreshed = await contextManager.refreshContextForAgents()
    print("  Context refresh successful: \(refreshed)")
    
    // Verify context was updated from agents
    let projectContextExists = !contextManager.getContextSummary(type: .project).isEmpty
    print("  Project context populated from planning agent: \(projectContextExists)")
    
    let conversationContextExists = !contextManager.getContextSummary(type: .conversation).isEmpty
    print("  Conversation context populated from conversation agent: \(conversationContextExists)")
    
    // Test getting combined context
    let combined = contextManager.getCombinedContext(types: [.project, .conversation])
    print("  Combined context contains project info: \(combined.contains("mock project context"))")
    print("  Combined context contains conversation info: \(combined.contains("Conversation History"))")
    
    return initialized && planningAgent.isConnectedToContextManager && 
           conversationAgent.isConnectedToContextManager && refreshed && 
           projectContextExists && conversationContextExists
}

@available(macOS 10.15, *)
func runAllTests() async -> Bool {
    print("\n=== Starting Phase 5.2 Context Management Tests ===\n")
    
    var allTestsPassed = true
    
    // Run Context Storage Tests
    let storageTestPassed = await testContextStorage()
    print("\nContext Storage Tests: \(storageTestPassed ? "✅ PASSED" : "❌ FAILED")")
    allTestsPassed = allTestsPassed && storageTestPassed
    
    // Run Agent Integration Tests
    let integrationTestPassed = await testAgentIntegration()
    print("\nAgent Integration Tests: \(integrationTestPassed ? "✅ PASSED" : "❌ FAILED")")
    allTestsPassed = allTestsPassed && integrationTestPassed
    
    print("\n=== Phase 5.2 Context Management Tests \(allTestsPassed ? "✅ PASSED" : "❌ FAILED") ===\n")
    
    return allTestsPassed
}

// MARK: - Main Execution

if #available(macOS 10.15, *) {
    // Create a task to run the async tests
    Task {
        let success = await runAllTests()
        exit(success ? 0 : 1)
    }
    
    // Keep the main thread running
    RunLoop.main.run()
} else {
    print("This test requires macOS 10.15 or later.")
    exit(1)
}
