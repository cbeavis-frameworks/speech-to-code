import Foundation
import Combine

/// Manages automated workflows and task execution sequences for the SpeechToCode app
@available(macOS 10.15, *)
class WorkflowManager: ObservableObject {
    /// Workflow state
    enum WorkflowState: Equatable {
        case idle
        case executing
        case paused
        case completed
        case error(String)
        
        // Custom equality implementation for Equatable
        static func == (lhs: WorkflowState, rhs: WorkflowState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.executing, .executing),
                 (.paused, .paused),
                 (.completed, .completed):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    /// Workflow type
    enum WorkflowType: String, CaseIterable, Identifiable, Codable {
        case codeReview = "Code Review"
        case projectSetup = "Project Setup"
        case unitTestCreation = "Unit Test Creation"
        case bugFix = "Bug Fix"
        case documentation = "Documentation"
        case customWorkflow = "Custom Workflow"
        
        var id: String { rawValue }
    }
    
    /// Structure that defines a workflow step
    struct WorkflowStep: Identifiable {
        let id: UUID
        let name: String
        let description: String
        var isCompleted: Bool
        var result: String?
        let agentType: AgentOrchestrator.AgentType
        let action: String
        var estimatedDuration: TimeInterval
        
        init(name: String, description: String, agentType: AgentOrchestrator.AgentType, action: String, estimatedDuration: TimeInterval = 5.0) {
            self.id = UUID()
            self.name = name
            self.description = description
            self.isCompleted = false
            self.result = nil
            self.agentType = agentType
            self.action = action
            self.estimatedDuration = estimatedDuration
        }
    }
    
    /// Structure that defines a complete workflow
    struct Workflow: Identifiable {
        let id: UUID
        var name: String
        var description: String
        var type: WorkflowType
        var steps: [WorkflowStep]
        var createdAt: Date
        var updatedAt: Date
        var isCustomizable: Bool
        
        init(name: String, description: String, type: WorkflowType, steps: [WorkflowStep], isCustomizable: Bool = false) {
            self.id = UUID()
            self.name = name
            self.description = description
            self.type = type
            self.steps = steps
            self.createdAt = Date()
            self.updatedAt = Date()
            self.isCustomizable = isCustomizable
        }
    }
    
    /// The current state of the workflow manager
    @Published var state: WorkflowState = .idle
    
    /// Progress of the current workflow (0.0 to 1.0)
    @Published var progress: Double = 0.0
    
    /// Current workflow being executed
    @Published var currentWorkflow: Workflow?
    
    /// Index of the current step being executed
    @Published var currentStepIndex: Int = 0
    
    /// Available workflow templates
    @Published var workflowTemplates: [Workflow] = []
    
    /// Custom workflows created by the user
    @Published var customWorkflows: [Workflow] = []
    
    /// Orchestrator reference for agent interaction
    private weak var orchestrator: AgentOrchestrator?
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize the workflow manager
    /// - Parameter orchestrator: The agent orchestrator
    init(orchestrator: AgentOrchestrator? = nil) {
        self.orchestrator = orchestrator
        initializeWorkflowTemplates()
    }
    
    /// Connect to agent orchestrator
    /// - Parameter orchestrator: The orchestrator to connect to
    func connectToOrchestrator(_ orchestrator: AgentOrchestrator) {
        self.orchestrator = orchestrator
    }
    
    // MARK: - Workflow Management
    
    /// Initialize workflow templates
    private func initializeWorkflowTemplates() {
        // Create standard workflow templates
        let codeReviewWorkflow = createCodeReviewWorkflow()
        let projectSetupWorkflow = createProjectSetupWorkflow()
        let unitTestWorkflow = createUnitTestWorkflow()
        let bugFixWorkflow = createBugFixWorkflow()
        let documentationWorkflow = createDocumentationWorkflow()
        
        // Add templates to the list
        workflowTemplates = [
            codeReviewWorkflow,
            projectSetupWorkflow,
            unitTestWorkflow,
            bugFixWorkflow,
            documentationWorkflow
        ]
    }
    
    /// Start executing a workflow
    /// - Parameter workflow: The workflow to execute
    /// - Returns: Boolean indicating success
    @discardableResult
    func startWorkflow(_ workflow: Workflow) -> Bool {
        // Check if there's already a workflow in progress
        guard state == .idle || state == .completed else {
            state = .error("Cannot start a new workflow while another is in progress")
            return false
        }
        
        // Set current workflow and reset progress
        currentWorkflow = workflow
        currentStepIndex = 0
        progress = 0.0
        state = .executing
        
        // Start execution of first step
        executeNextStep()
        
        return true
    }
    
    /// Execute the next step in the workflow
    /// - Returns: Boolean indicating if there are more steps to execute
    @discardableResult
    private func executeNextStep() -> Bool {
        guard let workflow = currentWorkflow else {
            state = .error("No workflow in progress")
            return false
        }
        
        // Check if we've completed all steps
        if currentStepIndex >= workflow.steps.count {
            completeWorkflow()
            return false
        }
        
        // Get the current step
        let step = workflow.steps[currentStepIndex]
        
        // Log the step execution
        print("Executing workflow step: \(step.name)")
        
        // Execute the step based on agent type
        executeStep(step)
        
        return true
    }
    
    /// Execute a specific workflow step
    /// - Parameter step: The step to execute
    private func executeStep(_ step: WorkflowStep) {
        Task {
            // Execute step based on agent type and action
            switch step.agentType {
            case .conversation:
                if let agent = orchestrator?.getConversationAgent() {
                    _ = await agent.processUserInput(step.action)
                }
            case .planning:
                if let agent = orchestrator?.getPlanningAgent() {
                    // Update the project context
                    await agent.updateProjectContext()
                }
            case .terminal:
                if let controller = orchestrator?.terminalController {
                    controller.sendCommand(step.action)
                }
            case .context:
                if let manager = orchestrator?.getContextManager() {
                    manager.updateContextSummary(step.action, type: .taskStatus)
                }
            }
            
            // Simulate step execution time
            try? await Task.sleep(nanoseconds: UInt64(step.estimatedDuration * 1_000_000_000))
            
            // Mark step as completed
            await completeStep(at: currentStepIndex, result: "Step executed successfully")
            
            // Move to next step
            await MainActor.run {
                currentStepIndex += 1
                progress = Double(currentStepIndex) / Double(currentWorkflow?.steps.count ?? 1)
                
                // Execute next step
                if !executeNextStep() {
                    // All steps completed
                    completeWorkflow()
                }
            }
        }
    }
    
    /// Mark a step as completed
    /// - Parameters:
    ///   - index: The index of the step
    ///   - result: The result of the step
    private func completeStep(at index: Int, result: String) async {
        await MainActor.run {
            guard var workflow = currentWorkflow,
                  index < workflow.steps.count else {
                return
            }
            
            // Mark step as completed
            workflow.steps[index].isCompleted = true
            workflow.steps[index].result = result
            currentWorkflow = workflow
        }
    }
    
    /// Complete the current workflow
    private func completeWorkflow() {
        state = .completed
        progress = 1.0
        print("Workflow completed: \(currentWorkflow?.name ?? "Unknown")")
    }
    
    /// Pause the current workflow
    func pauseWorkflow() {
        guard state == .executing else { return }
        state = .paused
    }
    
    /// Resume the current workflow
    func resumeWorkflow() {
        guard state == .paused else { return }
        state = .executing
        executeNextStep()
    }
    
    /// Cancel the current workflow
    func cancelWorkflow() {
        currentWorkflow = nil
        currentStepIndex = 0
        progress = 0.0
        state = .idle
    }
    
    // MARK: - Custom Workflow Management
    
    /// Create a new custom workflow
    /// - Parameters:
    ///   - name: The name of the workflow
    ///   - description: The description of the workflow
    ///   - steps: The steps of the workflow
    /// - Returns: The created workflow
    func createCustomWorkflow(name: String, description: String, steps: [WorkflowStep]) -> Workflow {
        let workflow = Workflow(
            name: name,
            description: description,
            type: .customWorkflow,
            steps: steps,
            isCustomizable: true
        )
        
        // Add to custom workflows
        customWorkflows.append(workflow)
        
        return workflow
    }
    
    /// Save a custom workflow
    /// - Parameter workflow: The workflow to save
    /// - Returns: Success indicator
    func saveCustomWorkflow(_ workflow: Workflow) -> Bool {
        // Find and update existing workflow or add new one
        if let index = customWorkflows.firstIndex(where: { $0.id == workflow.id }) {
            var updatedWorkflow = workflow
            updatedWorkflow.updatedAt = Date()
            customWorkflows[index] = updatedWorkflow
        } else {
            var newWorkflow = workflow
            newWorkflow.updatedAt = Date()
            customWorkflows.append(newWorkflow)
        }
        
        return true
    }
    
    /// Delete a custom workflow
    /// - Parameter id: The ID of the workflow to delete
    /// - Returns: Success indicator
    func deleteCustomWorkflow(id: UUID) -> Bool {
        customWorkflows.removeAll { $0.id == id }
        return true
    }
    
    // MARK: - Progress Reporting
    
    /// Generate a report for the current workflow
    /// - Returns: The report as a string
    func generateWorkflowReport() -> String {
        guard let workflow = currentWorkflow else {
            return "No workflow in progress"
        }
        
        var report = "# Workflow Report: \(workflow.name)\n\n"
        report += "**Type:** \(workflow.type.rawValue)\n"
        report += "**Description:** \(workflow.description)\n"
        report += "**Progress:** \(Int(progress * 100))%\n\n"
        
        report += "## Steps\n\n"
        
        for (index, step) in workflow.steps.enumerated() {
            let status = step.isCompleted ? "✅ Completed" : (index == currentStepIndex ? "⏳ In Progress" : "⏸ Pending")
            report += "### \(index + 1). \(step.name) - \(status)\n"
            report += "**Description:** \(step.description)\n"
            
            if let result = step.result {
                report += "**Result:** \(result)\n"
            }
            
            report += "\n"
        }
        
        return report
    }
    
    // MARK: - Predefined Workflow Templates
    
    /// Create a code review workflow template
    /// - Returns: The workflow
    private func createCodeReviewWorkflow() -> Workflow {
        let steps: [WorkflowStep] = [
            WorkflowStep(
                name: "Project Analysis",
                description: "Analyze the project structure and identify key components",
                agentType: .planning,
                action: "analyze project structure"
            ),
            WorkflowStep(
                name: "Code Quality Check",
                description: "Check code quality and identify potential issues",
                agentType: .terminal,
                action: "swiftlint"
            ),
            WorkflowStep(
                name: "Architecture Review",
                description: "Review the project architecture and identify improvements",
                agentType: .conversation,
                action: "review architecture"
            ),
            WorkflowStep(
                name: "Documentation Verification",
                description: "Verify that code is properly documented",
                agentType: .conversation,
                action: "check documentation"
            ),
            WorkflowStep(
                name: "Generate Report",
                description: "Generate a comprehensive code review report",
                agentType: .planning,
                action: "generate code review report"
            )
        ]
        
        return Workflow(
            name: "Comprehensive Code Review",
            description: "A comprehensive code review workflow that analyzes project structure, checks code quality, reviews architecture, and verifies documentation.",
            type: .codeReview,
            steps: steps
        )
    }
    
    /// Create a project setup workflow template
    /// - Returns: The workflow
    private func createProjectSetupWorkflow() -> Workflow {
        let steps: [WorkflowStep] = [
            WorkflowStep(
                name: "Project Initialization",
                description: "Initialize project structure and configuration",
                agentType: .planning,
                action: "initialize project"
            ),
            WorkflowStep(
                name: "Create Core Files",
                description: "Create essential project files and directories",
                agentType: .terminal,
                action: "mkdir -p SpeechToCode/Models SpeechToCode/Views SpeechToCode/Controllers"
            ),
            WorkflowStep(
                name: "Setup Dependencies",
                description: "Install and configure project dependencies",
                agentType: .terminal,
                action: "swift package init"
            ),
            WorkflowStep(
                name: "Configure Build System",
                description: "Configure the build system and project settings",
                agentType: .conversation,
                action: "configure build system"
            ),
            WorkflowStep(
                name: "Initialize Git Repository",
                description: "Initialize Git repository and create initial commit",
                agentType: .terminal,
                action: "git init && git add . && git commit -m 'Initial commit'"
            )
        ]
        
        return Workflow(
            name: "Project Setup",
            description: "A project setup workflow that initializes project structure, creates core files, sets up dependencies, and configures the build system.",
            type: .projectSetup,
            steps: steps
        )
    }
    
    /// Create a unit test workflow template
    /// - Returns: The workflow
    private func createUnitTestWorkflow() -> Workflow {
        let steps: [WorkflowStep] = [
            WorkflowStep(
                name: "Identify Test Targets",
                description: "Identify components that need testing",
                agentType: .planning,
                action: "identify test targets"
            ),
            WorkflowStep(
                name: "Create Test Plan",
                description: "Create a comprehensive test plan",
                agentType: .planning,
                action: "create test plan"
            ),
            WorkflowStep(
                name: "Generate Unit Tests",
                description: "Generate unit tests for identified components",
                agentType: .conversation,
                action: "generate unit tests"
            ),
            WorkflowStep(
                name: "Run Tests",
                description: "Run generated tests and collect results",
                agentType: .terminal,
                action: "swift test"
            ),
            WorkflowStep(
                name: "Generate Test Report",
                description: "Generate a test coverage report",
                agentType: .planning,
                action: "generate test report"
            )
        ]
        
        return Workflow(
            name: "Unit Test Creation",
            description: "A unit test creation workflow that identifies test targets, creates a test plan, generates unit tests, runs tests, and generates a test report.",
            type: .unitTestCreation,
            steps: steps
        )
    }
    
    /// Create a bug fix workflow template
    /// - Returns: The workflow
    private func createBugFixWorkflow() -> Workflow {
        let steps: [WorkflowStep] = [
            WorkflowStep(
                name: "Analyze Bug Report",
                description: "Analyze the bug report and understand the issue",
                agentType: .conversation,
                action: "analyze bug report"
            ),
            WorkflowStep(
                name: "Reproduce Bug",
                description: "Attempt to reproduce the reported bug",
                agentType: .terminal,
                action: "reproduce bug"
            ),
            WorkflowStep(
                name: "Debug Issue",
                description: "Debug the issue and identify the root cause",
                agentType: .conversation,
                action: "debug issue"
            ),
            WorkflowStep(
                name: "Implement Fix",
                description: "Implement a fix for the identified issue",
                agentType: .conversation,
                action: "implement fix"
            ),
            WorkflowStep(
                name: "Verify Fix",
                description: "Verify that the fix resolves the issue",
                agentType: .terminal,
                action: "verify fix"
            ),
            WorkflowStep(
                name: "Update Tests",
                description: "Update tests to cover the fixed issue",
                agentType: .conversation,
                action: "update tests"
            )
        ]
        
        return Workflow(
            name: "Bug Fix",
            description: "A bug fix workflow that analyzes the bug report, reproduces the bug, debugs the issue, implements a fix, verifies the fix, and updates tests.",
            type: .bugFix,
            steps: steps
        )
    }
    
    /// Create a documentation workflow template
    /// - Returns: The workflow
    private func createDocumentationWorkflow() -> Workflow {
        let steps: [WorkflowStep] = [
            WorkflowStep(
                name: "Analyze Project Structure",
                description: "Analyze the project structure and identify components to document",
                agentType: .planning,
                action: "analyze project for documentation"
            ),
            WorkflowStep(
                name: "Generate API Documentation",
                description: "Generate API documentation for public interfaces",
                agentType: .conversation,
                action: "generate API documentation"
            ),
            WorkflowStep(
                name: "Create User Guide",
                description: "Create a comprehensive user guide",
                agentType: .conversation,
                action: "create user guide"
            ),
            WorkflowStep(
                name: "Create README",
                description: "Create or update the project README",
                agentType: .conversation,
                action: "create README"
            ),
            WorkflowStep(
                name: "Generate Documentation Website",
                description: "Generate a documentation website",
                agentType: .terminal,
                action: "generate documentation site"
            )
        ]
        
        return Workflow(
            name: "Documentation",
            description: "A documentation workflow that analyzes the project structure, generates API documentation, creates a user guide, creates or updates the README, and generates a documentation website.",
            type: .documentation,
            steps: steps
        )
    }
}
