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
    
    /// Context manager reference
    private weak var contextManager: ContextManager?
    
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
            // Create default file-based storage in the application support directory
            let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let planDir = appSupportDir.appendingPathComponent("SpeechToCode/Plans", isDirectory: true)
            self.storage = FilePlanStorage(directory: planDir)
        }
        
        // Load existing plan data
        loadPlanData()
        
        // Load existing backups
        refreshBackupsList()
    }
    
    /// Connect to a Context Manager
    /// - Parameter manager: The context manager to connect
    func connectToContextManager(_ manager: ContextManager) {
        self.contextManager = manager
    }
    
    /// Load saved plan and context data
    private func loadPlanData() {
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
    func getProjectContext() -> String? {
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
        let currentTasks = planItems.filter { 
            $0.status == .inProgress || 
            ($0.status == .pending && $0.priority == .critical) 
        }
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
    
    /// Update the project context with the latest plan information
    /// - Returns: Success indicator
    @discardableResult
    func updateProjectContext() async -> Bool {
        // Generate a rich project context string based on the current plan
        var context = "# Project Context\n\n"
        
        // Add general project information
        context += "## Project Overview\n"
        context += projectContext.isEmpty ? "No project overview defined yet.\n\n" : projectContext + "\n\n"
        
        // Add current plan items summary
        context += "## Current Plan\n"
        
        // Group items by status
        let inProgressItems = planItems.filter { $0.status == .inProgress }
        let pendingItems = planItems.filter { $0.status == .pending }
        let completedItems = planItems.filter { $0.status == .completed }
        let blockedItems = planItems.filter { $0.status == .blocked }
        
        // Add in-progress items (highest priority)
        if !inProgressItems.isEmpty {
            context += "### In Progress\n"
            for item in inProgressItems {
                context += "- \(item.title) (\(item.priority.rawValue))\n"
            }
            context += "\n"
        }
        
        // Add blocked items (next highest priority as they need attention)
        if !blockedItems.isEmpty {
            context += "### Blocked\n"
            for item in blockedItems {
                context += "- \(item.title) - Reason: \(item.description.split(separator: ".").first ?? "")\n"
            }
            context += "\n"
        }
        
        // Add pending items
        if !pendingItems.isEmpty {
            context += "### Pending\n"
            // Only include high and critical priority pending items to save space
            let highPriorityPending = pendingItems.filter { 
                $0.priority == .high || $0.priority == .critical 
            }
            
            for item in highPriorityPending {
                context += "- \(item.title) (\(item.priority.rawValue))\n"
            }
            
            // If we have more pending items than shown, note that
            if highPriorityPending.count < pendingItems.count {
                context += "- ...(plus \(pendingItems.count - highPriorityPending.count) more pending items)\n"
            }
            context += "\n"
        }
        
        // Add recently completed items (limited to last 5)
        if !completedItems.isEmpty {
            context += "### Recently Completed\n"
            let recentlyCompleted = completedItems.sorted { 
                $0.updatedAt > $1.updatedAt 
            }.prefix(5)
            
            for item in recentlyCompleted {
                context += "- \(item.title)\n"
            }
            
            // If we have more completed items than shown, note that
            if recentlyCompleted.count < completedItems.count {
                context += "- ...(plus \(completedItems.count - recentlyCompleted.count) more completed items)\n"
            }
            context += "\n"
        }
        
        // Store this updated context
        self.projectContext = context
        
        // If we have a context manager, update it there too
        if let contextManager = contextManager {
            contextManager.updateProjectContext(context)
        }
        
        return true
    }
    
    /// Refresh the plan context and update it in the context manager
    /// - Returns: Success indicator
    @discardableResult
    func refreshProjectContext() async -> Bool {
        // Update our local project context
        let success = await updateProjectContext()
        
        // Update code structure context if possible
        updateCodeStructureContext()
        
        // Update task status context
        updateTaskStatusContext()
        
        return success
    }
    
    /// Update the code structure context in the context manager
    private func updateCodeStructureContext() {
        guard let contextManager = contextManager else {
            return
        }
        
        // Generate code structure context (could be enhanced to scan actual codebase)
        var codeStructureContext = "# Code Structure\n\n"
        
        // Extract code structure info from plan items
        let codeItems = planItems.filter { item in
            item.tags.contains("code") || item.tags.contains("implementation")
        }
        
        if !codeItems.isEmpty {
            codeStructureContext += "## Components\n"
            
            // Group by tag to identify components
            var componentGroups: [String: [PlanItem]] = [:]
            
            for item in codeItems {
                // Find component tags (assumed to be in format "component:name")
                let componentTags = item.tags.filter { $0.starts(with: "component:") }
                
                if !componentTags.isEmpty {
                    // Use the component as the group key
                    for tag in componentTags {
                        let component = tag.replacingOccurrences(of: "component:", with: "")
                        if componentGroups[component] == nil {
                            componentGroups[component] = []
                        }
                        componentGroups[component]?.append(item)
                    }
                } else {
                    // Use "other" as default group
                    if componentGroups["other"] == nil {
                        componentGroups["other"] = []
                    }
                    componentGroups["other"]?.append(item)
                }
            }
            
            // Add each component to the context
            for (component, items) in componentGroups {
                codeStructureContext += "### \(component.capitalized)\n"
                for item in items {
                    codeStructureContext += "- \(item.title)\n"
                }
                codeStructureContext += "\n"
            }
        } else {
            codeStructureContext += "No code structure information available yet.\n"
        }
        
        // Update in context manager
        contextManager.updateContextSummary(codeStructureContext, type: .codeStructure)
    }
    
    /// Update the task status context in the context manager
    private func updateTaskStatusContext() {
        guard let contextManager = contextManager else {
            return
        }
        
        // Generate task status context
        var taskStatusContext = "# Current Tasks\n\n"
        
        // Focus on current tasks (in progress and high priority pending)
        let currentTasks = planItems.filter { 
            $0.status == .inProgress || 
            ($0.status == .pending && $0.priority == .critical) 
        }
        
        if !currentTasks.isEmpty {
            for task in currentTasks {
                taskStatusContext += "## \(task.title)\n"
                taskStatusContext += "Status: \(task.status.rawValue)\n"
                taskStatusContext += "Priority: \(task.priority.rawValue)\n"
                taskStatusContext += "\(task.description)\n\n"
                
                // Add history entries for context on how the task has evolved
                if !task.historyEntries.isEmpty {
                    taskStatusContext += "### History\n"
                    // Only include the most recent 3 entries
                    let recentEntries = task.historyEntries.suffix(3)
                    for entry in recentEntries {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .short
                        dateFormatter.timeStyle = .short
                        let dateString = dateFormatter.string(from: entry.timestamp)
                        
                        taskStatusContext += "- \(dateString): \(entry.description)\n"
                    }
                    taskStatusContext += "\n"
                }
            }
        } else {
            taskStatusContext += "No active tasks at this time.\n"
        }
        
        // Update in context manager
        contextManager.updateContextSummary(taskStatusContext, type: .taskStatus)
    }
    
    /// Query plan information based on a query string
    /// - Parameter query: The query string
    /// - Returns: The result information
    func queryPlanInformation(_ query: String) -> String {
        // Set state to processing
        DispatchQueue.main.async {
            self.state = .processing
        }
        
        // Process the query to extract relevant information from the plan
        var result = ""
        
        // Convert query to lowercase for case-insensitive matching
        let lowercaseQuery = query.lowercased()
        
        // Check for different query types
        if lowercaseQuery.contains("status") && lowercaseQuery.contains("summary") {
            // Status summary request
            result = generateStatusSummary()
        } else if lowercaseQuery.contains("item") && (lowercaseQuery.contains("detail") || lowercaseQuery.contains("find")) {
            // Item details request - extract item title or ID from query
            if let itemIdentifier = extractItemIdentifier(from: query) {
                result = getItemDetails(identifier: itemIdentifier)
            } else {
                result = "Please specify an item title or ID to find details."
            }
        } else if lowercaseQuery.contains("plan") && lowercaseQuery.contains("summary") {
            // Plan summary request
            result = generatePlanSummary()
        } else if lowercaseQuery.contains("history") {
            // History request - optionally for a specific item
            if let itemIdentifier = extractItemIdentifier(from: query) {
                result = getItemHistory(identifier: itemIdentifier)
            } else {
                result = generatePlanHistory()
            }
        } else {
            // General query - search for matching items
            result = searchPlanItems(query: query)
        }
        
        // Set state back to idle
        DispatchQueue.main.async {
            self.state = .idle
        }
        
        return result
    }
    
    /// Load plan data from storage
    private func loadData() {
        do {
            planItems = try storage.loadPlan()
            projectContext = try storage.loadProjectContext()
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } catch {
            lastError = "Failed to load data: \(error.localizedDescription)"
            planItems = []
            projectContext = ""
        }
    }
    
    /// Generate a summary of the current plan status
    /// - Returns: Text summary of the current status
    private func generateStatusSummary() -> String {
        var summary = "# Current Plan Status\n\n"
        
        let completedItems = planItems.filter { $0.status == .completed }.count
        let inProgressItems = planItems.filter { $0.status == .inProgress }.count
        let pendingItems = planItems.filter { $0.status == .pending }.count
        let blockedItems = planItems.filter { $0.status == .blocked }.count
        let totalItems = planItems.count
        
        summary += "- **Total Items**: \(totalItems)\n"
        if totalItems > 0 {
            let completedPercent = Int(Double(completedItems) / Double(totalItems) * 100.0)
            let inProgressPercent = Int(Double(inProgressItems) / Double(totalItems) * 100.0)
            let pendingPercent = Int(Double(pendingItems) / Double(totalItems) * 100.0)
            let blockedPercent = Int(Double(blockedItems) / Double(totalItems) * 100.0)
            
            summary += "- **Completed**: \(completedItems) (\(completedPercent)%)\n"
            summary += "- **In Progress**: \(inProgressItems) (\(inProgressPercent)%)\n"
            summary += "- **Pending**: \(pendingItems) (\(pendingPercent)%)\n"
            summary += "- **Blocked**: \(blockedItems) (\(blockedPercent)%)\n\n"
        } else {
            summary += "- **Completed**: 0 (0%)\n"
            summary += "- **In Progress**: 0 (0%)\n"
            summary += "- **Pending**: 0 (0%)\n"
            summary += "- **Blocked**: 0 (0%)\n\n"
        }
        
        summary += "## Active Items\n\n"
        
        // Add active items
        let activeItems = planItems.filter { $0.status == .inProgress }
        if activeItems.isEmpty {
            summary += "No items currently in progress.\n\n"
        } else {
            for item in activeItems {
                summary += "- \(item.title) (ID: \(item.id))\n"
            }
            summary += "\n"
        }
        
        summary += "## Next Up\n\n"
        
        // Add upcoming items
        let upcomingItems = planItems.filter { $0.status == .pending }.prefix(3)
        if upcomingItems.isEmpty {
            summary += "No pending items left.\n\n"
        } else {
            for item in upcomingItems {
                summary += "- \(item.title) (ID: \(item.id))\n"
            }
            summary += "\n"
        }
        
        return summary
    }
    
    /// Extract an item identifier (title or ID) from a query string
    /// - Parameter query: The query string to extract from
    /// - Returns: The extracted identifier, if found
    private func extractItemIdentifier(from query: String) -> String? {
        // Look for patterns like "item ABC123" or "details for XYZ"
        let components = query.components(separatedBy: .whitespacesAndNewlines)
        
        // Look for a UUID string format
        for component in components {
            if let _ = UUID(uuidString: component) {
                return component
            }
        }
        
        // Try to extract title - look for quotation marks
        if let titleRange = query.range(of: "\"(.+?)\"", options: .regularExpression) {
            return String(query[titleRange]).replacingOccurrences(of: "\"", with: "")
        }
        
        // Look for keywords followed by potential title
        let titleMarkers = ["item", "task", "for", "about", "titled", "called", "named"]
        for marker in titleMarkers {
            if let range = query.range(of: "\(marker) ", options: .caseInsensitive) {
                let startIndex = range.upperBound
                if let endIndex = query[startIndex...].firstIndex(where: { $0 == "." || $0 == "?" || $0 == "," }) {
                    return String(query[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    return String(query[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return nil
    }
    
    /// Get details for a specific plan item
    /// - Parameter identifier: The item identifier (ID or title substring)
    /// - Returns: Formatted details of the item
    private func getItemDetails(identifier: String) -> String {
        // Check if we have a UUID
        if let itemId = UUID(uuidString: identifier),
           let item = planItems.first(where: { $0.id == itemId }) {
            return formatItemDetails(item)
        }
        
        // Otherwise search by title
        let matchingItems = planItems.filter { 
            $0.title.lowercased().contains(identifier.lowercased()) 
        }
        
        if matchingItems.isEmpty {
            return "No items found matching '\(identifier)'."
        } else if matchingItems.count == 1 {
            return formatItemDetails(matchingItems[0])
        } else {
            var result = "Found \(matchingItems.count) matching items:\n\n"
            for item in matchingItems {
                result += "- \(item.title) (ID: \(item.id), Status: \(item.status.rawValue))\n"
            }
            result += "\nPlease specify an exact ID for more details."
            return result
        }
    }
    
    /// Format the details of a plan item
    /// - Parameter item: The plan item
    /// - Returns: Formatted details
    private func formatItemDetails(_ item: PlanItem) -> String {
        var details = "# Item Details: \(item.title)\n\n"
        details += "- **ID**: \(item.id)\n"
        details += "- **Status**: \(item.status.rawValue)\n"
        details += "- **Priority**: \(item.priority.rawValue)\n"
        details += "- **Created**: \(formatDate(item.createdAt))\n"
        details += "- **Last Updated**: \(formatDate(item.updatedAt))\n"
        
        if !item.description.isEmpty {
            details += "\n## Description\n\n\(item.description)\n"
        }
        
        if !item.tags.isEmpty {
            details += "\n## Tags\n\n"
            for tag in item.tags {
                details += "- \(tag)\n"
            }
            details += "\n"
        }
        
        if !item.dependencies.isEmpty {
            details += "\n## Dependencies\n\n"
            for dependencyId in item.dependencies {
                if let dependencyItem = planItems.first(where: { $0.id == dependencyId }) {
                    details += "- \(dependencyItem.title) (ID: \(dependencyId), Status: \(dependencyItem.status.rawValue))\n"
                } else {
                    details += "- Unknown item (ID: \(dependencyId))\n"
                }
            }
        }
        
        // Show history entries for this item
        if !item.historyEntries.isEmpty {
            details += "\n## History\n\n"
            for entry in item.historyEntries.sorted(by: { $0.timestamp > $1.timestamp }).prefix(5) {
                details += "- \(formatDate(entry.timestamp)): \(entry.description)\n"
            }
            if item.historyEntries.count > 5 {
                details += "- ...\(item.historyEntries.count - 5) more entries\n"
            }
        }
        
        return details
    }
    
    /// Get the history for a specific plan item
    /// - Parameter identifier: The item identifier (ID or title substring)
    /// - Returns: Formatted history of the item
    private func getItemHistory(identifier: String) -> String {
        // Find the item
        var targetItems: [PlanItem] = []
        
        // Check if we have a UUID
        if let itemId = UUID(uuidString: identifier),
           let item = planItems.first(where: { $0.id == itemId }) {
            targetItems = [item]
        } else {
            // Title search
            targetItems = planItems.filter { 
                $0.title.lowercased().contains(identifier.lowercased()) 
            }
        }
        
        if targetItems.isEmpty {
            return "No items found matching '\(identifier)'."
        }
        
        if targetItems.count > 1 {
            var result = "Found \(targetItems.count) matching items. Please specify one:\n\n"
            for item in targetItems {
                result += "- \(item.title) (ID: \(item.id))\n"
            }
            return result
        }
        
        let item = targetItems[0]
        
        if item.historyEntries.isEmpty {
            return "No history entries found for '\(item.title)'."
        }
        
        var result = "# History for \(item.title) (ID: \(item.id))\n\n"
        
        for entry in item.historyEntries.sorted(by: { $0.timestamp > $1.timestamp }) {
            result += "## \(formatDate(entry.timestamp))\n"
            result += entry.description + "\n\n"
            
            if let previousStatus = entry.previousStatus, let newStatus = entry.newStatus {
                result += "Status changed from '\(previousStatus.rawValue)' to '\(newStatus.rawValue)'\n\n"
            }
        }
        
        return result
    }
    
    /// Generate a history of all plan changes
    /// - Returns: Formatted plan history
    private func generatePlanHistory() -> String {
        // Collect all history entries from all items
        var allHistoryEntries: [(itemId: UUID, itemTitle: String, entry: PlanItem.HistoryEntry)] = []
        
        for item in planItems {
            for entry in item.historyEntries {
                allHistoryEntries.append((itemId: item.id, itemTitle: item.title, entry: entry))
            }
        }
        
        if allHistoryEntries.isEmpty {
            return "No plan history available."
        }
        
        // Sort by timestamp (newest first)
        allHistoryEntries.sort(by: { $0.entry.timestamp > $1.entry.timestamp })
        
        var result = "# Plan History\n\n"
        
        // Get recent entries
        let recentEntries = allHistoryEntries.prefix(20)
        
        for historyItem in recentEntries {
            result += "- \(formatDate(historyItem.entry.timestamp)): \(historyItem.itemTitle) - \(historyItem.entry.description)\n"
        }
        
        if allHistoryEntries.count > 20 {
            result += "\n*...and \(allHistoryEntries.count - 20) more entries*"
        }
        
        return result
    }
    
    /// Search for plan items matching a query
    /// - Parameter query: The search query
    /// - Returns: Formatted search results
    private func searchPlanItems(query: String) -> String {
        let searchQuery = query.lowercased()
        
        // Search in titles, descriptions, and tags
        let matchingItems = planItems.filter { item in
            item.title.lowercased().contains(searchQuery) ||
            item.description.lowercased().contains(searchQuery) ||
            item.tags.contains(where: { $0.lowercased().contains(searchQuery) })
        }
        
        if matchingItems.isEmpty {
            return "No items found matching '\(query)'."
        }
        
        var result = "# Search Results for '\(query)'\n\n"
        result += "Found \(matchingItems.count) matching items:\n\n"
        
        for item in matchingItems {
            result += "## \(item.title) (ID: \(item.id))\n"
            result += "- **Status**: \(item.status.rawValue)\n"
            result += "- **Priority**: \(item.priority.rawValue)\n"
            
            // Show snippet of matching content for context
            if item.title.lowercased().contains(searchQuery) {
                result += "- **Matched in**: Title\n"
            }
            if item.description.lowercased().contains(searchQuery) {
                let snippet = getSnippet(from: item.description, containing: searchQuery)
                result += "- **Description match**: \"...\(snippet)...\"\n"
            }
            if item.tags.contains(where: { $0.lowercased().contains(searchQuery) }) {
                result += "- **Matched tags**: \(item.tags.filter { $0.lowercased().contains(searchQuery) }.joined(separator: ", "))\n"
            }
            result += "\n"
        }
        
        return result
    }
    
    /// Format a date
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Get a text snippet containing a search query
    /// - Parameters:
    ///   - text: The source text
    ///   - query: The query to find
    /// - Returns: A snippet of text
    private func getSnippet(from text: String, containing query: String) -> String {
        let lowerText = text.lowercased()
        guard let range = lowerText.range(of: query.lowercased()) else {
            return ""
        }
        
        let queryStartIndex = range.lowerBound
        
        // Get surrounding context (about 20 chars before and after)
        let snippetStart = text.index(queryStartIndex, offsetBy: -20, limitedBy: text.startIndex) ?? text.startIndex
        let queryEndIndex = range.upperBound
        let snippetEnd = text.index(queryEndIndex, offsetBy: 20, limitedBy: text.endIndex) ?? text.endIndex
        
        return String(text[snippetStart..<snippetEnd])
    }
}
