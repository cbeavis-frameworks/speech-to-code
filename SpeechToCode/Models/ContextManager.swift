import Foundation
import Combine

/// Manages context sharing between agents and provides context refreshing mechanisms
@available(macOS 10.15, *)
class ContextManager: ObservableObject {
    /// The current project context
    @Published var projectContext: String = ""
    
    /// The current context summaries for different components
    @Published var contextSummaries: [ContextType: String] = [:]
    
    /// Flag to indicate if the context manager is initialized
    @Published var isInitialized: Bool = false
    
    /// Context type enumeration for categorizing different types of context
    enum ContextType: String, Codable {
        case project          // Overall project context
        case conversation     // Recent conversation history
        case codeStructure    // Code structure and architecture
        case taskStatus       // Current task status and progress
        case systemStatus     // System status information
        case userPreferences  // User preferences and settings
    }
    
    /// Maximum token counts for different context types
    private var maxTokens: [ContextType: Int] = [
        .project: 2000,
        .conversation: 1500,
        .codeStructure: 1000,
        .taskStatus: 800,
        .systemStatus: 500,
        .userPreferences: 500
    ]
    
    /// References to other components
    private weak var planningAgent: PlanningAgent?
    private weak var conversationAgent: ConversationAgent?
    private weak var orchestrator: AgentOrchestrator?
    
    /// Storage for persistent context data
    private var contextStorage: ContextStorageProtocol
    
    /// Flag to track if a context refresh is in progress
    private var isRefreshing: Bool = false
    
    /// Protocol for context storage implementations
    protocol ContextStorageProtocol {
        /// Save context to storage
        /// - Parameters:
        ///   - context: The context to save
        ///   - type: The context type
        /// - Throws: Storage-related errors
        func saveContext(_ context: String, type: ContextType) throws
        
        /// Load context from storage
        /// - Parameter type: The context type to load
        /// - Returns: The loaded context
        /// - Throws: Storage-related errors
        func loadContext(type: ContextType) throws -> String
        
        /// List available context types in storage
        /// - Returns: List of available context types
        /// - Throws: Storage-related errors
        func listAvailableContextTypes() throws -> [ContextType]
        
        /// Delete a context type from storage
        /// - Parameter type: The context type to delete
        /// - Throws: Storage-related errors
        func deleteContext(type: ContextType) throws
    }
    
    /// File-based implementation of the ContextStorageProtocol
    class FileContextStorage: ContextStorageProtocol {
        /// Base directory for context storage
        private let baseDirectory: URL
        
        /// Initialize with a base directory
        /// - Parameter directory: The directory to use for storage
        init(directory: URL) {
            self.baseDirectory = directory
            
            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        /// Save context to a file
        func saveContext(_ context: String, type: ContextType) throws {
            let fileName = "\(type.rawValue)_context.txt"
            let fileURL = baseDirectory.appendingPathComponent(fileName)
            try context.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        /// Load context from a file
        func loadContext(type: ContextType) throws -> String {
            let fileName = "\(type.rawValue)_context.txt"
            let fileURL = baseDirectory.appendingPathComponent(fileName)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return try String(contentsOf: fileURL, encoding: .utf8)
            } else {
                return ""
            }
        }
        
        /// List available context types in storage
        func listAvailableContextTypes() throws -> [ContextType] {
            // Get all files in the directory
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)
            
            // Filter for context files
            var availableTypes: [ContextType] = []
            for url in contents {
                let filename = url.lastPathComponent
                if filename.hasSuffix("_context.txt") {
                    // Extract the context type from the filename
                    let typeString = filename.replacingOccurrences(of: "_context.txt", with: "")
                    if let type = ContextType(rawValue: typeString) {
                        availableTypes.append(type)
                    }
                }
            }
            
            return availableTypes
        }
        
        /// Delete a context type from storage
        func deleteContext(type: ContextType) throws {
            let fileName = "\(type.rawValue)_context.txt"
            let fileURL = baseDirectory.appendingPathComponent(fileName)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
    }
    
    /// Initialize a new Context Manager
    /// - Parameter storage: The storage implementation to use
    init(storage: ContextStorageProtocol? = nil) {
        // Use provided storage or create default file-based storage
        if let storage = storage {
            self.contextStorage = storage
        } else {
            // Create default file-based storage in the application support directory
            let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let contextDir = appSupportDir.appendingPathComponent("SpeechToCode/Context", isDirectory: true)
            self.contextStorage = FileContextStorage(directory: contextDir)
        }
    }
    
    /// Connect to a Planning Agent
    /// - Parameter agent: The planning agent to connect
    func connectPlanningAgent(_ agent: PlanningAgent) {
        self.planningAgent = agent
    }
    
    /// Connect to a Conversation Agent
    /// - Parameter agent: The conversation agent to connect
    func connectConversationAgent(_ agent: ConversationAgent) {
        self.conversationAgent = agent
    }
    
    /// Connect to an Agent Orchestrator
    /// - Parameter orchestrator: The agent orchestrator to connect
    func connectOrchestrator(_ orchestrator: AgentOrchestrator) {
        self.orchestrator = orchestrator
    }
    
    /// Initialize the context manager
    /// - Returns: Success indicator
    @discardableResult
    func initialize() async -> Bool {
        // Load any saved context
        do {
            try loadContextFromStorage()
            isInitialized = true
            return true
        } catch {
            print("Error initializing context manager: \(error)")
            isInitialized = false
            return false
        }
    }
    
    /// Load context from storage
    private func loadContextFromStorage() throws {
        // Get available context types
        let availableTypes = try contextStorage.listAvailableContextTypes()
        
        // Load each type
        for type in availableTypes {
            let context = try contextStorage.loadContext(type: type)
            if type == .project {
                projectContext = context
            } else {
                contextSummaries[type] = context
            }
        }
    }
    
    /// Save context to storage
    private func saveContextToStorage() {
        // Save project context
        do {
            try contextStorage.saveContext(projectContext, type: .project)
        } catch {
            print("Error saving project context: \(error)")
        }
        
        // Save each context summary
        for (type, summary) in contextSummaries {
            do {
                try contextStorage.saveContext(summary, type: type)
            } catch {
                print("Error saving \(type) context: \(error)")
            }
        }
    }
    
    /// Create or update project context
    /// - Parameter context: The project context
    /// - Returns: Success indicator
    @discardableResult
    func updateProjectContext(_ context: String) -> Bool {
        projectContext = context
        saveContextToStorage()
        
        // Trigger context refresh for dependent components
        Task {
            await refreshContextForAgents()
        }
        
        return true
    }
    
    /// Create or update a context summary
    /// - Parameters:
    ///   - summary: The context summary
    ///   - type: The context type
    /// - Returns: Success indicator
    @discardableResult
    func updateContextSummary(_ summary: String, type: ContextType) -> Bool {
        if type == .project {
            // Use updateProjectContext for project type
            return updateProjectContext(summary)
        }
        
        // For other types, update the summary dictionary
        contextSummaries[type] = summary
        saveContextToStorage()
        
        return true
    }
    
    /// Get the project context
    /// - Returns: The project context
    func getProjectContext() -> String {
        return projectContext
    }
    
    /// Get a context summary
    /// - Parameter type: The context type
    /// - Returns: The context summary
    func getContextSummary(type: ContextType) -> String {
        if type == .project {
            return projectContext
        }
        return contextSummaries[type] ?? ""
    }
    
    /// Get a combined context within token limits
    /// - Parameter types: The context types to include
    /// - Returns: The combined context string
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
    
    /// Refresh context for all agents
    /// - Returns: Success indicator
    @discardableResult
    func refreshContextForAgents() async -> Bool {
        guard !isRefreshing, isInitialized else {
            return false
        }
        
        isRefreshing = true
        
        // Create a task ID with the orchestrator if available
        let taskId = orchestrator?.addPendingTask()
        
        // Refresh project context from planning agent if available
        if let planningAgent = planningAgent {
            if let context = planningAgent.getProjectContext() {
                updateProjectContext(context)
            }
        }
        
        // Generate conversation summary if conversation agent is available
        if let conversationAgent = conversationAgent {
            let conversationSummary = await conversationAgent.generateConversationSummary()
            updateContextSummary(conversationSummary, type: .conversation)
        }
        
        // Update system status summary
        let systemSummary = generateSystemStatusSummary()
        updateContextSummary(systemSummary, type: .systemStatus)
        
        // Complete the task if we have an orchestrator
        if let taskId = taskId {
            orchestrator?.completePendingTask(taskId)
        }
        
        isRefreshing = false
        return true
    }
    
    /// Generate a summary of the system status
    /// - Returns: The system status summary
    private func generateSystemStatusSummary() -> String {
        var summary = "System Status as of \(Date())\n\n"
        
        // Add orchestrator status if available
        if let orchestrator = orchestrator {
            summary += "Orchestrator State: \(stateDescription(for: orchestrator.state))\n"
            summary += "Active Agents: \(orchestrator.activeAgents)\n"
            summary += "Pending Tasks: \(orchestrator.pendingTasks)\n\n"
        }
        
        // Add conversation agent status if available
        if let conversationAgent = conversationAgent {
            summary += "Conversation Agent State: \(stateDescription(for: conversationAgent.state))\n"
            summary += "Voice Listening: \(conversationAgent.isListening ? "Active" : "Inactive")\n\n"
        }
        
        // Add planning agent status if available
        if let planningAgent = planningAgent {
            summary += "Planning Agent State: \(stateDescription(for: planningAgent.state))\n"
            summary += "Plan Items Count: \(planningAgent.planItems.count)\n\n"
        }
        
        return summary
    }
    
    /// Get a string description of a state
    /// - Parameter state: The state to describe
    /// - Returns: String description
    private func stateDescription(for state: Any) -> String {
        // Convert various state enums to readable strings
        if let state = state as? AgentOrchestrator.OrchestratorState {
            switch state {
            case .initializing: return "Initializing"
            case .ready: return "Ready"
            case .running: return "Running"
            case .paused: return "Paused"
            case .shutdownInProgress: return "Shutdown In Progress"
            case .shutdown: return "Shutdown"
            case .error(let message): return "Error: \(message)"
            }
        } else if let state = state as? ConversationAgent.AgentState {
            switch state {
            case .idle: return "Idle"
            case .processing: return "Processing"
            case .listeningForVoice: return "Listening For Voice"
            case .processingVoice: return "Processing Voice"
            case .speaking: return "Speaking"
            case .error(let message): return "Error: \(message)"
            }
        } else if let state = state as? PlanningAgent.AgentState {
            switch state {
            case .idle: return "Idle"
            case .processing: return "Processing"
            case .error(let message): return "Error: \(message)"
            }
        }
        
        return String(describing: state)
    }
    
    /// Generate a summarized version of a context to fit within token limits
    /// - Parameters:
    ///   - context: The full context
    ///   - type: The context type
    /// - Returns: The summarized context
    func summarizeContext(_ context: String, type: ContextType) -> String {
        // Get the token limit for this type
        let tokenLimit = maxTokens[type] ?? 1000
        
        // Simple token counting (approximate characters / 4 as tokens)
        let approximateTokens = context.count / 4
        
        if approximateTokens <= tokenLimit {
            return context // No need to summarize
        }
        
        // If we need to summarize, use a simple approach of keeping most recent and most important parts
        
        // Split into sections (assuming markdown-like format with headings)
        let sections = context.components(separatedBy: "\n##")
        
        // If no clear sections, just truncate
        if sections.count <= 1 {
            // Keep the first part and the last part to maintain context
            let characterLimit = tokenLimit * 4
            if context.count <= characterLimit {
                return context
            }
            
            // Keep first third and last third, removing the middle
            let firstThird = context.prefix(characterLimit / 2)
            let lastThird = context.suffix(characterLimit / 2)
            
            return String(firstThird) + "\n\n[...content summarized...]\n\n" + String(lastThird)
        }
        
        // With sections, keep the first section (intro) and most recent sections up to the token limit
        var summarized = sections[0]
        var currentTokens = sections[0].count / 4
        
        // Add the most recent sections first (reverse order)
        for section in sections.reversed().dropFirst() {
            let sectionTokens = section.count / 4
            if currentTokens + sectionTokens <= tokenLimit {
                summarized = "##\(section)\n" + summarized
                currentTokens += sectionTokens
            } else {
                // Can't fit more sections
                break
            }
        }
        
        // Add a note about summarization
        summarized = summarized + "\n\n[Context has been summarized to fit within token limits]"
        
        return summarized
    }
    
    /// Delete a context
    /// - Parameter type: The context type to delete
    /// - Returns: Success indicator
    @discardableResult
    func deleteContext(type: ContextType) -> Bool {
        do {
            try contextStorage.deleteContext(type: type)
            if type == .project {
                projectContext = ""
            } else {
                contextSummaries.removeValue(forKey: type)
            }
            return true
        } catch {
            print("Error deleting context: \(error)")
            return false
        }
    }
}
