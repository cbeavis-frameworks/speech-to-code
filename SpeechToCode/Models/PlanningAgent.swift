import Foundation

/// Planning agent model to maintain project context, track tasks, and provide long-term memory
class PlanningAgent: ObservableObject {
    /// Current state of the agent
    enum AgentState {
        case idle
        case processing
        case error(String)
    }
    
    /// Plan item structure for task tracking
    struct PlanItem: Identifiable, Codable {
        var id = UUID()
        var title: String
        var description: String
        var status: PlanItemStatus
        var createdAt: Date
        var updatedAt: Date
        
        enum PlanItemStatus: String, Codable {
            case pending
            case inProgress
            case completed
            case blocked
        }
        
        init(title: String, description: String, status: PlanItemStatus = .pending) {
            self.title = title
            self.description = description
            self.status = status
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }
    
    /// Plan storage protocol for persistence
    protocol PlanStorage {
        func savePlan(items: [PlanItem]) throws
        func loadPlan() throws -> [PlanItem]
        func saveProjectContext(context: String) throws
        func loadProjectContext() throws -> String
    }
    
    /// File-based plan storage implementation
    class FileBasedPlanStorage: PlanStorage {
        private let planFile: URL
        private let contextFile: URL
        
        init(directory: URL) {
            self.planFile = directory.appendingPathComponent("plan.json")
            self.contextFile = directory.appendingPathComponent("context.txt")
            
            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        func savePlan(items: [PlanItem]) throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(items)
            try data.write(to: planFile)
        }
        
        func loadPlan() throws -> [PlanItem] {
            guard FileManager.default.fileExists(atPath: planFile.path) else {
                return []
            }
            
            let data = try Data(contentsOf: planFile)
            let decoder = JSONDecoder()
            return try decoder.decode([PlanItem].self, from: data)
        }
        
        func saveProjectContext(context: String) throws {
            try context.write(to: contextFile, atomically: true, encoding: .utf8)
        }
        
        func loadProjectContext() throws -> String {
            guard FileManager.default.fileExists(atPath: contextFile.path) else {
                return ""
            }
            
            return try String(contentsOf: contextFile, encoding: .utf8)
        }
    }
    
    /// Published properties for SwiftUI integration
    @Published var state: AgentState = .idle
    @Published var planItems: [PlanItem] = []
    @Published var projectContext: String = ""
    
    /// Storage implementation
    private let storage: PlanStorage
    
    /// Initialize a new Planning Agent
    /// - Parameter storage: The storage implementation to use
    init(storage: PlanStorage? = nil) {
        // Use provided storage or create default file-based storage
        if let storage = storage {
            self.storage = storage
        } else {
            // Get documents directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let planningDirectory = documentsDirectory.appendingPathComponent("SpeechToCode/Planning")
            self.storage = FileBasedPlanStorage(directory: planningDirectory)
        }
        
        // Load saved data
        loadData()
    }
    
    /// Load saved plan and context data
    private func loadData() {
        do {
            planItems = try storage.loadPlan()
            projectContext = try storage.loadProjectContext()
        } catch {
            state = .error("Failed to load planning data: \(error.localizedDescription)")
        }
    }
    
    /// Save current plan and context data
    private func saveData() {
        do {
            try storage.savePlan(items: planItems)
            try storage.saveProjectContext(context: projectContext)
        } catch {
            state = .error("Failed to save planning data: \(error.localizedDescription)")
        }
    }
    
    /// Add a new plan item
    /// - Parameter item: The plan item to add
    func addPlanItem(_ item: PlanItem) {
        planItems.append(item)
        saveData()
    }
    
    /// Update an existing plan item
    /// - Parameter item: The updated plan item
    func updatePlanItem(_ item: PlanItem) {
        if let index = planItems.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = item
            updatedItem.updatedAt = Date()
            planItems[index] = updatedItem
            saveData()
        }
    }
    
    /// Remove a plan item
    /// - Parameter id: The ID of the item to remove
    func removePlanItem(id: UUID) {
        planItems.removeAll { $0.id == id }
        saveData()
    }
    
    /// Update the project context
    /// - Parameter context: The new project context
    func updateProjectContext(_ context: String) {
        projectContext = context
        saveData()
    }
    
    /// Get current project context
    /// - Returns: The project context as a string
    func getProjectContext() -> String {
        return projectContext
    }
    
    /// Get the current plan as a formatted string
    /// - Returns: String representation of the plan
    func getCurrentPlan() -> String {
        var planText = "# Current Plan\n\n"
        
        if planItems.isEmpty {
            planText += "No plan items yet.\n"
        } else {
            for item in planItems {
                planText += "## \(item.title) (\(item.status.rawValue))\n"
                planText += "\(item.description)\n\n"
            }
        }
        
        return planText
    }
    
    /// Process user input for planning purposes
    /// - Parameter userInput: The user input text
    func processUserInput(_ userInput: String) {
        // In a real implementation, this would parse user input for planning-related commands
        // For now, we'll just log it
        print("Planning agent received user input: \(userInput)")
    }
    
    /// Receive a message from another agent
    /// - Parameter message: The message received
    func receiveMessage(_ message: AgentMessage) {
        // Process message from another agent
        if message.messageType == .conversationToPlanningAgent {
            // Parse message content for planning-related commands
            // This is a simplified implementation
            print("Planning agent received message: \(message.content)")
        }
    }
}
