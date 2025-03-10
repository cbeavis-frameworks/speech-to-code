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
        var historyEntries: [HistoryEntry]
        
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
        
        /// History entry for tracking changes to a plan item
        struct HistoryEntry: Codable {
            var timestamp: Date
            var description: String
            var previousStatus: PlanItemStatus?
            var newStatus: PlanItemStatus?
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
            self.historyEntries = [HistoryEntry(timestamp: Date(), description: "Item created", previousStatus: nil, newStatus: status)]
        }
        
        /// Update the status of this plan item
        /// - Parameter newStatus: The new status
        mutating func updateStatus(_ newStatus: PlanItemStatus) {
            let previousStatus = self.status
            self.status = newStatus
            self.updatedAt = Date()
            
            // Add history entry
            self.historyEntries.append(HistoryEntry(
                timestamp: Date(),
                description: "Status changed from \(previousStatus.rawValue) to \(newStatus.rawValue)",
                previousStatus: previousStatus,
                newStatus: newStatus
            ))
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
    @Published var planVersions: [PlanVersion] = []
    
    /// Structure to represent a plan version
    struct PlanVersion: Identifiable, Codable {
        var id = UUID()
        var name: String
        var createdAt: Date
        var description: String
        var items: [PlanItem]
    }
    
    /// Information about a plan backup
    struct PlanBackupInfo: Codable, Identifiable {
        /// Unique identifier for the backup
        var id: String
        /// User-provided name for the backup (optional)
        var name: String?
        /// Date the backup was created
        var createdAt: Date
    }
    
    /// Protocol defining the required methods for a plan storage system
    protocol PlanStorageProtocol {
        /// Save plan items to storage
        /// - Parameter items: The plan items to save
        /// - Throws: Storage-related errors
        func savePlan(items: [PlanningAgent.PlanItem]) throws
        
        /// Load plan items from storage
        /// - Returns: The loaded plan items
        /// - Throws: Storage-related errors
        func loadPlan() throws -> [PlanningAgent.PlanItem]
        
        /// Save project context to storage
        /// - Parameter context: The project context to save
        /// - Throws: Storage-related errors
        func saveProjectContext(context: String) throws
        
        /// Load project context from storage
        /// - Returns: The loaded project context
        /// - Throws: Storage-related errors
        func loadProjectContext() throws -> String
        
        /// Create a backup of the current plan data
        /// - Parameter name: Optional name for the backup
        /// - Returns: Identifier for the backup
        /// - Throws: Backup-related errors
        func createBackup(name: String?) throws -> String
        
        /// Restore plan data from a backup
        /// - Parameter identifier: The backup identifier
        /// - Throws: Restore-related errors
        func restoreFromBackup(identifier: String) throws
        
        /// List available backups
        /// - Returns: List of backup information
        /// - Throws: Storage-related errors
        func listBackups() throws -> [PlanBackupInfo]
        
        /// Delete a backup
        /// - Parameter identifier: The backup identifier
        /// - Throws: Storage-related errors
        func deleteBackup(identifier: String) throws
    }
    
    /// A file-based implementation of the PlanStorageProtocol
    class FilePlanStorage: PlanStorageProtocol {
        /// Base directory for plan storage
        private let baseDirectory: URL
        
        /// Initialize with a base directory
        /// - Parameter directory: The directory to use for storage
        init(directory: URL) {
            self.baseDirectory = directory
            
            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        /// Implement PlanStorageProtocol methods
        func savePlan(items: [PlanningAgent.PlanItem]) throws {
            // Implementation provided as a stub for build purposes
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(items)
            try data.write(to: baseDirectory.appendingPathComponent("plan.json"))
        }
        
        func loadPlan() throws -> [PlanningAgent.PlanItem] {
            // Implementation provided as a stub for build purposes
            let planFile = baseDirectory.appendingPathComponent("plan.json")
            
            if FileManager.default.fileExists(atPath: planFile.path) {
                let data = try Data(contentsOf: planFile)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode([PlanningAgent.PlanItem].self, from: data)
            }
            
            return []
        }
        
        func saveProjectContext(context: String) throws {
            // Implementation provided as a stub for build purposes
            try context.write(to: baseDirectory.appendingPathComponent("context.txt"), atomically: true, encoding: .utf8)
        }
        
        func loadProjectContext() throws -> String {
            // Implementation provided as a stub for build purposes
            let contextFile = baseDirectory.appendingPathComponent("context.txt")
            
            if FileManager.default.fileExists(atPath: contextFile.path) {
                return try String(contentsOf: contextFile, encoding: .utf8)
            }
            
            return ""
        }
        
        func createBackup(name: String?) throws -> String {
            // Implementation provided as a stub for build purposes
            return UUID().uuidString
        }
        
        func restoreFromBackup(identifier: String) throws {
            // Implementation provided as a stub for build purposes
        }
        
        func listBackups() throws -> [PlanBackupInfo] {
            // Implementation provided as a stub for build purposes
            return []
        }
        
        func deleteBackup(identifier: String) throws {
            // Implementation provided as a stub for build purposes
        }
    }
    
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
        loadVersions()
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
        if message.messageType == .requestPlanUpdate {
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
    
    /// Create a new plan from scratch
    /// - Parameters:
    ///   - name: Name of the plan
    ///   - description: Description of the plan
    /// - Returns: True if successful, false otherwise
    func createNewPlan(name: String, description: String) -> Bool {
        // Save the current plan as a version first
        if !planItems.isEmpty {
            saveCurrentPlanAsVersion(name: "Auto-saved before new plan", description: "Automatically saved before creating new plan '\(name)'")
        }
        
        // Clear existing plan items
        planItems = []
        saveData()
        
        return true
    }
    
    /// Save the current plan as a version with name and description
    /// - Parameters:
    ///   - name: Name of the version
    ///   - description: Description of the version
    /// - Returns: The identifier of the created version
    @discardableResult
    func saveCurrentPlanAsVersion(name: String, description: String) -> UUID {
        let version = PlanVersion(
            name: name,
            createdAt: Date(),
            description: description,
            items: planItems
        )
        planVersions.append(version)
        saveVersions()
        return version.id
    }
    
    /// Load a plan version
    /// - Parameter versionId: The ID of the version to load
    /// - Returns: True if successful, false otherwise
    func loadPlanVersion(versionId: UUID) -> Bool {
        guard let version = planVersions.first(where: { $0.id == versionId }) else {
            lastError = "Version not found"
            return false
        }
        
        // Save current plan as a version first
        if !planItems.isEmpty {
            saveCurrentPlanAsVersion(name: "Auto-saved before loading version", description: "Automatically saved before loading version '\(version.name)'")
        }
        
        // Replace current plan with version
        planItems = version.items
        saveData()
        
        return true
    }
    
    /// Delete a plan version
    /// - Parameter versionId: The ID of the version to delete
    /// - Returns: True if successful, false otherwise
    func deletePlanVersion(versionId: UUID) -> Bool {
        let initialCount = planVersions.count
        planVersions.removeAll { $0.id == versionId }
        
        if planVersions.count != initialCount {
            saveVersions()
            return true
        } else {
            lastError = "Version not found"
            return false
        }
    }
    
    /// Save plan versions to storage
    private func saveVersions() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(planVersions)
            
            // Get documents directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let planningDirectory = documentsDirectory.appendingPathComponent("SpeechToCode/Planning")
            let versionsFile = planningDirectory.appendingPathComponent("versions.json")
            
            try FileManager.default.createDirectory(at: planningDirectory, withIntermediateDirectories: true)
            try data.write(to: versionsFile)
            
            lastError = nil
        } catch {
            state = .error("Failed to save plan versions: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }
    
    /// Load plan versions from storage
    private func loadVersions() {
        // Get documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let planningDirectory = documentsDirectory.appendingPathComponent("SpeechToCode/Planning")
        let versionsFile = planningDirectory.appendingPathComponent("versions.json")
        
        if FileManager.default.fileExists(atPath: versionsFile.path) {
            do {
                let data = try Data(contentsOf: versionsFile)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                planVersions = try decoder.decode([PlanVersion].self, from: data)
                lastError = nil
            } catch {
                state = .error("Failed to load plan versions: \(error.localizedDescription)")
                lastError = error.localizedDescription
            }
        }
    }
    
    /// Get history for a plan item
    /// - Parameter itemId: The ID of the item
    /// - Returns: Array of history entries
    func getPlanItemHistory(itemId: UUID) -> [PlanItem.HistoryEntry]? {
        guard let item = planItems.first(where: { $0.id == itemId }) else {
            return nil
        }
        
        return item.historyEntries
    }
    
    /// Add a comment to a plan item's history
    /// - Parameters:
    ///   - itemId: The ID of the item
    ///   - comment: The comment to add
    /// - Returns: True if successful, false otherwise
    func addCommentToPlanItem(itemId: UUID, comment: String) -> Bool {
        guard let index = planItems.firstIndex(where: { $0.id == itemId }) else {
            return false
        }
        
        var item = planItems[index]
        item.historyEntries.append(PlanItem.HistoryEntry(
            timestamp: Date(),
            description: "Comment: \(comment)",
            previousStatus: nil,
            newStatus: nil
        ))
        item.updatedAt = Date()
        
        planItems[index] = item
        saveData()
        
        return true
    }
    
    /// Initialize the agent with test data (for development and testing)
    func initializeWithTestData() {
        // Create some test plan items
        let item1 = PlanItem(
            title: "Implement voice recognition",
            description: "Add voice recognition capabilities to the app",
            status: .completed,
            priority: .high,
            tags: ["voice", "input"]
        )
        
        let item2 = PlanItem(
            title: "Create terminal view",
            description: "Implement the terminal view UI component",
            status: .completed,
            priority: .critical,
            tags: ["ui", "terminal"]
        )
        
        let item3 = PlanItem(
            title: "Integrate Claude CLI",
            description: "Add support for Claude CLI integration",
            status: .inProgress,
            priority: .medium,
            tags: ["ai", "claude"]
        )
        
        var item4 = PlanItem(
            title: "Implement multi-agent architecture",
            description: "Create planning and conversation agents",
            status: .pending,
            priority: .high,
            tags: ["architecture", "ai"]
        )
        
        // Add dependencies
        item4.addDependency(item1.id)
        item4.addDependency(item3.id)
        
        // Add the items to the plan
        planItems = [item1, item2, item3, item4]
        
        // Add some history
        _ = addCommentToPlanItem(itemId: item3.id, comment: "Started implementation, need to research API requirements")
        
        // Create a test version
        _ = saveCurrentPlanAsVersion(name: "Initial Plan", description: "Initial project plan with core features")
        
        // Save everything
        saveData()
    }
    
    /// Generate a summary of the project plan
    /// - Returns: A concise summary of the plan
    func generatePlanSummary() -> String {
        let totalItems = planItems.count
        let pendingCount = planItems.filter { $0.status == .pending }.count
        let inProgressCount = planItems.filter { $0.status == .inProgress }.count
        let completedCount = planItems.filter { $0.status == .completed }.count
        let blockedCount = planItems.filter { $0.status == .blocked }.count
        
        let highPriorityCount = planItems.filter { $0.priority == .high || $0.priority == .critical }.count
        
        var summary = "# Project Plan Summary\n\n"
        summary += "## Progress\n"
        summary += "- Total Tasks: \(totalItems)\n"
        summary += "- Completed: \(completedCount) (\(totalItems > 0 ? Int(Double(completedCount) / Double(totalItems) * 100) : 0)%)\n"
        summary += "- In Progress: \(inProgressCount)\n"
        summary += "- Pending: \(pendingCount)\n"
        summary += "- Blocked: \(blockedCount)\n\n"
        
        summary += "## Priorities\n"
        summary += "- High Priority Tasks: \(highPriorityCount)\n\n"
        
        // Add top 3 current tasks
        let currentTasks = planItems.filter { $0.status == .inProgress || $0.status == .pending }
            .sorted { 
                if $0.priority == $1.priority {
                    return $0.status == .inProgress && $1.status != .inProgress
                }
                return $0.priority.rawValue > $1.priority.rawValue
            }
            .prefix(3)
        
        summary += "## Current Focus\n"
        if currentTasks.isEmpty {
            summary += "No active tasks.\n"
        } else {
            for task in currentTasks {
                summary += "- \(task.title) (\(task.status.rawValue), \(task.priority.rawValue) priority)\n"
            }
        }
        
        return summary
    }
    
    /// Process messages from the conversation agent
    /// - Parameter message: The message to process
    /// - Returns: Response message
    func processAgentMessage(_ message: AgentMessage) -> AgentMessage {
        // Process messages from other agents
        switch message.messageType {
        case .requestPlanUpdate:
            if handlePlanUpdateRequest(message.content) {
                return AgentMessage(messageType: .planUpdateConfirmation, sender: "PlanningAgent", recipient: message.sender, content: "Plan updated successfully")
            } else {
                return AgentMessage(messageType: .error, sender: "PlanningAgent", recipient: message.sender, content: "Invalid plan update request")
            }
        case .requestPlanQuery:
            if let result = handlePlanQuery(message.content) {
                return AgentMessage(messageType: .planQueryResult, sender: "PlanningAgent", recipient: message.sender, content: result)
            } else {
                return AgentMessage(messageType: .error, sender: "PlanningAgent", recipient: message.sender, content: "Invalid plan query")
            }
        case .requestProjectContext:
            return AgentMessage(messageType: .projectContextResult, sender: "PlanningAgent", recipient: message.sender, content: projectContext)
        case .requestPlanSummary:
            return AgentMessage(messageType: .planSummaryResult, sender: "PlanningAgent", recipient: message.sender, content: generatePlanSummary())
        default:
            return AgentMessage(messageType: .error, sender: "PlanningAgent", recipient: message.sender, content: "Unsupported message type")
        }
    }
    
    /// Handle a request to update the plan
    /// - Parameter request: The request string
    private func handlePlanUpdateRequest(_ request: String) -> Bool {
        // Extract plan item details from the request
        if let title = extractTitle(from: request),
           let description = extractDescription(from: request) {
            
            // Extract additional properties if available
            let priority = extractPriority(from: request) ?? .medium
            let tags = extractTags(from: request)
            
            // Create and add the new plan item
            let newItem = PlanItem(
                title: title,
                description: description,
                priority: priority,
                tags: tags
            )
            
            addPlanItem(newItem)
            return true
        }
        return false
    }
    
    /// Extract priority from a plan update request
    /// - Parameter request: The request string
    /// - Returns: Extracted priority or nil
    private func extractPriority(from request: String) -> PlanItem.Priority? {
        // Check for priority keywords
        let lowercaseRequest = request.lowercased()
        
        if lowercaseRequest.contains("priority: critical") || lowercaseRequest.contains("critical priority") {
            return .critical
        } else if lowercaseRequest.contains("priority: high") || lowercaseRequest.contains("high priority") {
            return .high
        } else if lowercaseRequest.contains("priority: low") || lowercaseRequest.contains("low priority") {
            return .low
        } else if lowercaseRequest.contains("priority: medium") || lowercaseRequest.contains("medium priority") {
            return .medium
        }
        
        return nil
    }
    
    /// Extract tags from a plan update request
    /// - Parameter request: The request string
    /// - Returns: Array of extracted tags
    private func extractTags(from request: String) -> [String] {
        // Look for tags in format: Tags: tag1, tag2, tag3
        var tags: [String] = []
        
        if let tagsLine = request.split(separator: "\n")
            .first(where: { $0.lowercased().contains("tags:") }) {
            let tagsText = String(tagsLine.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines))
            tags = tagsText.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
        
        return tags
    }
    
    /// Handle a plan query
    /// - Parameter query: The query string
    /// - Returns: Result of the query
    private func handlePlanQuery(_ query: String) -> String? {
        let lowercaseQuery = query.lowercased()
        
        if lowercaseQuery.contains("summary") {
            return generatePlanSummary()
        } else if lowercaseQuery.contains("high priority") || lowercaseQuery.contains("critical") {
            return generatePriorityBasedReport(priorities: [.high, .critical])
        } else if lowercaseQuery.contains("in progress") {
            return generateStatusBasedReport(status: .inProgress)
        } else if lowercaseQuery.contains("pending") {
            return generateStatusBasedReport(status: .pending)
        } else if lowercaseQuery.contains("blocked") {
            return generateStatusBasedReport(status: .blocked)
        } else if lowercaseQuery.contains("completed") {
            return generateStatusBasedReport(status: .completed)
        } else {
            return getCurrentPlan()
        }
    }
    
    /// Generate a report based on item priority
    /// - Parameter priorities: The priorities to filter by
    /// - Returns: Formatted report
    private func generatePriorityBasedReport(priorities: [PlanItem.Priority]) -> String {
        let filteredItems = planItems.filter { priorities.contains($0.priority) }
        
        var report = "# Priority Report\n\n"
        if filteredItems.isEmpty {
            report += "No items matching the specified priorities.\n"
        } else {
            report += "## Items with priority: \(priorities.map { $0.rawValue }.joined(separator: ", "))\n\n"
            for item in filteredItems.sorted(by: { $0.priority.rawValue > $1.priority.rawValue }) {
                report += formatPlanItem(item)
            }
        }
        
        return report
    }
    
    /// Generate a report based on item status
    /// - Parameter status: The status to filter by
    /// - Returns: Formatted report
    private func generateStatusBasedReport(status: PlanItem.PlanItemStatus) -> String {
        let filteredItems = planItems.filter { $0.status == status }
        
        var report = "# Status Report\n\n"
        if filteredItems.isEmpty {
            report += "No items with status: \(status.rawValue).\n"
        } else {
            report += "## Items with status: \(status.rawValue)\n\n"
            for item in filteredItems.sorted(by: { $0.priority.rawValue > $1.priority.rawValue }) {
                report += formatPlanItem(item)
            }
        }
        
        return report
    }
    
    /// Save the current state of the project before making major changes
    func createSafetyVersion() {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        let name = "Auto-save \(timestamp)"
        let description = "Automatically saved version before significant changes"
        let _ = saveCurrentPlanAsVersion(name: name, description: description)
    }
    
    /// Create a version snapshot for demonstration purposes
    private func createDemoVersions() {
        // Create a few versions to show the history
        let _ = saveCurrentPlanAsVersion(name: "Initial Plan", description: "First draft of the project plan")
        
        // Update a few items
        if let index = planItems.firstIndex(where: { $0.title.contains("Research") }) {
            planItems[index].status = .inProgress
            planItems[index].updatedAt = Date()
        }
        
        // Save the updated plan as a new version
        let _ = saveCurrentPlanAsVersion(name: "Research Started", description: "Research phase initiated")
        
        // Update another item
        if let index = planItems.firstIndex(where: { $0.title.contains("Design") }) {
            planItems[index].status = .inProgress
            planItems[index].updatedAt = Date()
        }
        
        // Save the updated plan as a new version
        let _ = saveCurrentPlanAsVersion(name: "Design Phase", description: "Design phase initiated")
    }
}
