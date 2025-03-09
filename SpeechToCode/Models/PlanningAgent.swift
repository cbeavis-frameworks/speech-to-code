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
        var priority: Priority
        var tags: [String]
        var dependencies: [UUID]
        
        enum PlanItemStatus: String, Codable {
            case pending
            case inProgress
            case completed
            case blocked
            case cancelled
        }
        
        enum Priority: String, Codable {
            case low
            case medium
            case high
            case critical
        }
        
        init(title: String, 
             description: String, 
             status: PlanItemStatus = .pending, 
             priority: Priority = .medium,
             tags: [String] = [],
             dependencies: [UUID] = []) {
            self.title = title
            self.description = description
            self.status = status
            self.priority = priority
            self.tags = tags
            self.dependencies = dependencies
            self.createdAt = Date()
            self.updatedAt = Date()
        }
        
        /// Update the status of this plan item
        /// - Parameter newStatus: The new status
        mutating func updateStatus(_ newStatus: PlanItemStatus) {
            self.status = newStatus
            self.updatedAt = Date()
        }
        
        /// Add a dependency to this plan item
        /// - Parameter dependencyId: The ID of the dependency
        mutating func addDependency(_ dependencyId: UUID) {
            if !dependencies.contains(dependencyId) {
                dependencies.append(dependencyId)
                updatedAt = Date()
            }
        }
        
        /// Remove a dependency from this plan item
        /// - Parameter dependencyId: The ID of the dependency to remove
        mutating func removeDependency(_ dependencyId: UUID) {
            dependencies.removeAll { $0 == dependencyId }
            updatedAt = Date()
        }
    }
    
    /// Published properties for SwiftUI integration
    @Published var state: AgentState = .idle
    @Published var planItems: [PlanItem] = []
    @Published var projectContext: String = ""
    @Published var lastError: String? = nil
    @Published var backups: [PlanBackupInfo] = []
    
    /// Storage implementation
    private let storage: PlanStorageProtocol
    
    /// Initialize a new Planning Agent
    /// - Parameter storage: The storage implementation to use
    init(storage: PlanStorageProtocol? = nil) {
        // Use provided storage or create default file-based storage
        if let storage = storage {
            self.storage = storage
        } else {
            // Get documents directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let planningDirectory = documentsDirectory.appendingPathComponent("SpeechToCode/Planning")
            self.storage = FilePlanStorage(directory: planningDirectory)
        }
        
        // Load saved data
        loadData()
        refreshBackupsList()
    }
    
    /// Load saved plan and context data
    private func loadData() {
        do {
            planItems = try storage.loadPlan()
            projectContext = try storage.loadProjectContext()
            lastError = nil
        } catch {
            state = .error("Failed to load planning data: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }
    
    /// Save current plan and context data
    private func saveData() {
        do {
            try storage.savePlan(items: planItems)
            try storage.saveProjectContext(context: projectContext)
            lastError = nil
        } catch {
            state = .error("Failed to save planning data: \(error.localizedDescription)")
            lastError = error.localizedDescription
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
            // Group items by status
            let pendingItems = planItems.filter { $0.status == .pending }
            let inProgressItems = planItems.filter { $0.status == .inProgress }
            let completedItems = planItems.filter { $0.status == .completed }
            let blockedItems = planItems.filter { $0.status == .blocked }
            let cancelledItems = planItems.filter { $0.status == .cancelled }
            
            // Format pending items
            if !pendingItems.isEmpty {
                planText += "## Pending\n\n"
                for item in pendingItems.sorted(by: { $0.priority.rawValue < $1.priority.rawValue }) {
                    planText += formatPlanItem(item)
                }
            }
            
            // Format in-progress items
            if !inProgressItems.isEmpty {
                planText += "## In Progress\n\n"
                for item in inProgressItems.sorted(by: { $0.priority.rawValue < $1.priority.rawValue }) {
                    planText += formatPlanItem(item)
                }
            }
            
            // Format blocked items
            if !blockedItems.isEmpty {
                planText += "## Blocked\n\n"
                for item in blockedItems {
                    planText += formatPlanItem(item)
                }
            }
            
            // Format completed items
            if !completedItems.isEmpty {
                planText += "## Completed\n\n"
                for item in completedItems {
                    planText += formatPlanItem(item)
                }
            }
            
            // Format cancelled items
            if !cancelledItems.isEmpty {
                planText += "## Cancelled\n\n"
                for item in cancelledItems {
                    planText += formatPlanItem(item)
                }
            }
        }
        
        return planText
    }
    
    /// Format a plan item for display
    /// - Parameter item: The plan item to format
    /// - Returns: Formatted string representation of the item
    private func formatPlanItem(_ item: PlanItem) -> String {
        var itemText = "### \(item.title) (\(item.priority.rawValue))\n"
        itemText += "\(item.description)\n"
        
        if !item.tags.isEmpty {
            itemText += "**Tags**: \(item.tags.joined(separator: ", "))\n"
        }
        
        if !item.dependencies.isEmpty {
            itemText += "**Dependencies**: "
            let dependencyTitles = item.dependencies.compactMap { id in
                planItems.first(where: { $0.id == id })?.title
            }
            itemText += dependencyTitles.joined(separator: ", ")
            itemText += "\n"
        }
        
        itemText += "\n"
        return itemText
    }
    
    /// Process user input for planning purposes
    /// - Parameter userInput: The user input text
    func processUserInput(_ userInput: String) {
        // Look for planning-related commands in user input
        let lowercaseInput = userInput.lowercased()
        
        if lowercaseInput.contains("create backup") || lowercaseInput.contains("backup plan") {
            createBackup(name: "User-requested backup")
            return
        }
        
        if lowercaseInput.contains("list backups") {
            refreshBackupsList()
            return
        }
        
        if lowercaseInput.contains("add task") || lowercaseInput.contains("create task") {
            // Extract task details from input
            // This is a simplified implementation - in a real app, we'd use NLP
            let taskTitle = extractTitle(from: userInput)
            let taskDescription = extractDescription(from: userInput)
            
            let newTask = PlanItem(
                title: taskTitle ?? "New Task",
                description: taskDescription ?? "Task created from voice command",
                status: .pending
            )
            
            addPlanItem(newTask)
            return
        }
        
        // In a real implementation, we would have more sophisticated parsing
        print("Planning agent received user input: \(userInput)")
    }
    
    /// Basic title extraction - would be improved with proper NLP in production
    private func extractTitle(from input: String) -> String? {
        // Very basic implementation - find text after "titled" or "called"
        if let range = input.range(of: "titled [\"']?([^\"']+)[\"']?", options: .regularExpression) {
            let match = input[range]
            return String(match.split(separator: " ").dropFirst().joined(separator: " "))
                .trimmingCharacters(in: .punctuationCharacters)
        }
        
        if let range = input.range(of: "called [\"']?([^\"']+)[\"']?", options: .regularExpression) {
            let match = input[range]
            return String(match.split(separator: " ").dropFirst().joined(separator: " "))
                .trimmingCharacters(in: .punctuationCharacters)
        }
        
        return nil
    }
    
    /// Basic description extraction - would be improved with proper NLP in production
    private func extractDescription(from input: String) -> String? {
        // Very basic implementation - find text after "description"
        if let range = input.range(of: "description [\"']?([^\"']+)[\"']?", options: .regularExpression) {
            let match = input[range]
            return String(match.split(separator: " ").dropFirst().joined(separator: " "))
                .trimmingCharacters(in: .punctuationCharacters)
        }
        
        return nil
    }
    
    /// Process command from message
    /// - Parameter message: The message content
    func processCommandFromMessage(_ message: String) {
        processUserInput(message) // Reuse the same processing logic
    }
    
    /// Receive a message from another agent
    /// - Parameter message: The message received
    func receiveMessage(_ message: Any) {
        // Check if it's an AgentMessage type
        guard let message = message as? AgentMessage else { return }
        
        // Process message from another agent
        if message.messageType == .planningRequest {
            // Parse message content for planning-related commands
            processCommandFromMessage(message.content)
        }
    }
    
    // MARK: - Backup and Recovery
    
    /// Create a backup of the current plan data
    /// - Parameter name: Optional name for the backup
    /// - Returns: Identifier for the backup
    @discardableResult
    func createBackup(name: String? = nil) -> String? {
        do {
            let backupId = try storage.createBackup(name: name)
            refreshBackupsList()
            return backupId
        } catch {
            lastError = "Failed to create backup: \(error.localizedDescription)"
            state = .error(lastError!)
            return nil
        }
    }
    
    /// Restore plan data from a backup
    /// - Parameter identifier: The backup identifier
    func restoreFromBackup(identifier: String) {
        do {
            try storage.restoreFromBackup(identifier: identifier)
            loadData() // Reload data after restoration
            refreshBackupsList()
        } catch {
            lastError = "Failed to restore from backup: \(error.localizedDescription)"
            state = .error(lastError!)
        }
    }
    
    /// Refresh the list of available backups
    func refreshBackupsList() {
        do {
            backups = try storage.listBackups()
        } catch {
            lastError = "Failed to list backups: \(error.localizedDescription)"
            state = .error(lastError!)
        }
    }
    
    /// Delete a backup
    /// - Parameter identifier: The backup identifier
    func deleteBackup(identifier: String) {
        do {
            try storage.deleteBackup(identifier: identifier)
            refreshBackupsList()
        } catch {
            lastError = "Failed to delete backup: \(error.localizedDescription)"
            state = .error(lastError!)
        }
    }
}
