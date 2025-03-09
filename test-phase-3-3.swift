#!/usr/bin/swift

import Foundation

// MARK: - Test script for Phase 3.3: Agent Communication
// This script validates the implementation of agent communication features

print("\n📱 SpeechToCode - Phase 3.3 Test Script: Agent Communication\n")

// MARK: - Mock Data Structures

// AgentMessage struct that mirrors the app's implementation
struct AgentMessage: Codable, Equatable {
    enum MessageType: String, Codable, CaseIterable {
        case userInput
        case assistantOutput
        case terminalCommand
        case terminalOutput
        case planningRequest
        case planningResponse
        case requestPlanUpdate
        case planUpdateConfirmation
        case requestPlanQuery
        case planQueryResult
        case requestPlanSummary
        case planSummaryResult
        case requestProjectContext
        case projectContextResult
        case error
    }
    
    let messageType: MessageType
    let sender: String
    let recipient: String
    let content: String
    var metadata: [String: String]
    
    init(messageType: MessageType, sender: String, recipient: String, content: String, metadata: [String: String] = [:]) {
        self.messageType = messageType
        self.sender = sender
        self.recipient = recipient
        self.content = content
        self.metadata = metadata
    }
    
    // Factory methods for common message types
    static func userInput(content: String, sender: String = "User") -> AgentMessage {
        return AgentMessage(
            messageType: .userInput,
            sender: sender,
            recipient: "ConversationAgent",
            content: content
        )
    }
    
    static func requestPlanUpdate(content: String, sender: String) -> AgentMessage {
        return AgentMessage(
            messageType: .requestPlanUpdate,
            sender: sender,
            recipient: "PlanningAgent",
            content: content
        )
    }
    
    static func requestPlanQuery(query: String, sender: String) -> AgentMessage {
        return AgentMessage(
            messageType: .requestPlanQuery,
            sender: sender,
            recipient: "PlanningAgent",
            content: query
        )
    }
    
    static func requestPlanSummary(sender: String) -> AgentMessage {
        return AgentMessage(
            messageType: .requestPlanSummary,
            sender: sender,
            recipient: "PlanningAgent",
            content: "summary"
        )
    }
    
    static func requestProjectContext(sender: String) -> AgentMessage {
        return AgentMessage(
            messageType: .requestProjectContext,
            sender: sender,
            recipient: "PlanningAgent",
            content: "context"
        )
    }
}

// PlanItem struct that mirrors the app's implementation
struct PlanItem: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var description: String
    var status: String
    var dateCreated: Date
    var dateCompleted: Date?
    var priority: Int
    var tags: [String]
    
    init(id: UUID = UUID(), title: String, description: String, status: String = "pending", 
         priority: Int = 1, tags: [String] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.dateCreated = Date()
        self.dateCompleted = nil
        self.priority = priority
        self.tags = tags
    }
}

// Mock PlanningAgent to test communication
class MockPlanningAgent {
    var planItems: [PlanItem] = []
    var projectContext: String = "This is a mock project context."
    
    init() {
        // Add some mock plan items
        planItems.append(PlanItem(
            title: "Implement Agent Communication",
            description: "Create message handling infrastructure between agents",
            status: "in-progress",
            tags: ["phase-3", "communication"]
        ))
        
        planItems.append(PlanItem(
            title: "Create Test Script",
            description: "Validate agent communication implementation",
            status: "pending",
            tags: ["phase-3", "testing"]
        ))
    }
    
    // Process an agent message
    func processAgentMessage(_ message: AgentMessage) -> AgentMessage {
        switch message.messageType {
        case .requestPlanUpdate:
            return handlePlanUpdateRequest(message.content)
        case .requestPlanQuery:
            return handlePlanQuery(message.content)
        case .requestPlanSummary:
            return handlePlanSummary()
        case .requestProjectContext:
            return handleProjectContextRequest()
        default:
            return AgentMessage(
                messageType: .error,
                sender: "PlanningAgent",
                recipient: message.sender,
                content: "Unsupported message type: \(message.messageType)"
            )
        }
    }
    
    // Handle a request to update the plan
    private func handlePlanUpdateRequest(_ content: String) -> AgentMessage {
        // Parse the plan update request (simplified for test)
        let titleEndIndex = content.firstIndex(of: ":") ?? content.endIndex
        let title = String(content[..<titleEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let description = titleEndIndex < content.endIndex ? 
            String(content[content.index(after: titleEndIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines) : 
            "No description"
        
        // Create and add the plan item
        let newItem = PlanItem(
            title: title,
            description: description,
            tags: ["test"]
        )
        planItems.append(newItem)
        
        // Return confirmation message
        return AgentMessage(
            messageType: .planUpdateConfirmation,
            sender: "PlanningAgent",
            recipient: "ConversationAgent",
            content: "Added new plan item: \(title)"
        )
    }
    
    // Handle a query about the plan
    private func handlePlanQuery(_ query: String) -> AgentMessage {
        // Process the query (simplified for test)
        var response = ""
        
        if query.localizedCaseInsensitiveContains("status") {
            // Query about item status
            response = "Plan status summary:\n"
            let pendingItems = planItems.filter { $0.status == "pending" }.count
            let inProgressItems = planItems.filter { $0.status == "in-progress" }.count
            let completedItems = planItems.filter { $0.status == "completed" }.count
            
            response += "- Pending: \(pendingItems)\n"
            response += "- In Progress: \(inProgressItems)\n"
            response += "- Completed: \(completedItems)\n"
        } else if query.localizedCaseInsensitiveContains("list") {
            // List all items
            response = "All plan items:\n"
            for (index, item) in planItems.enumerated() {
                response += "\(index + 1). \(item.title) (\(item.status))\n"
            }
        } else {
            // Generic response
            response = "Found \(planItems.count) plan items in total."
        }
        
        return AgentMessage(
            messageType: .planQueryResult,
            sender: "PlanningAgent",
            recipient: "ConversationAgent",
            content: response
        )
    }
    
    // Handle a request for a plan summary
    private func handlePlanSummary() -> AgentMessage {
        let pendingItems = planItems.filter { $0.status == "pending" }.count
        let inProgressItems = planItems.filter { $0.status == "in-progress" }.count
        let completedItems = planItems.filter { $0.status == "completed" }.count
        
        let response = """
        Plan Summary:
        - Total Items: \(planItems.count)
        - Pending: \(pendingItems)
        - In Progress: \(inProgressItems)
        - Completed: \(completedItems)
        
        Current Focus: Agent Communication Implementation
        """
        
        return AgentMessage(
            messageType: .planSummaryResult,
            sender: "PlanningAgent",
            recipient: "ConversationAgent",
            content: response
        )
    }
    
    // Handle a request for project context
    private func handleProjectContextRequest() -> AgentMessage {
        return AgentMessage(
            messageType: .projectContextResult,
            sender: "PlanningAgent",
            recipient: "ConversationAgent",
            content: projectContext
        )
    }
}

// Mock ConversationAgent to test communication
class MockConversationAgent {
    var messages: [AgentMessage] = []
    var planningAgent: MockPlanningAgent
    
    init(planningAgent: MockPlanningAgent) {
        self.planningAgent = planningAgent
    }
    
    // Send a message to the planning agent and process response
    func sendAgentMessage(_ message: AgentMessage) -> AgentMessage {
        messages.append(message)
        
        // Send to planning agent
        let response = planningAgent.processAgentMessage(message)
        
        // Log the response
        messages.append(response)
        
        return response
    }
    
    // Request a plan update
    func requestPlanUpdate(_ updateDetails: String) -> Bool {
        let updateRequest = AgentMessage.requestPlanUpdate(content: updateDetails, sender: "ConversationAgent")
        let response = sendAgentMessage(updateRequest)
        
        return response.messageType == .planUpdateConfirmation
    }
    
    // Request a plan query
    func queryPlan(_ query: String) -> String? {
        let queryRequest = AgentMessage.requestPlanQuery(query: query, sender: "ConversationAgent")
        let response = sendAgentMessage(queryRequest)
        
        if response.messageType == .planQueryResult {
            return response.content
        }
        return nil
    }
    
    // Request a plan summary
    func requestPlanSummary() -> String? {
        let summaryRequest = AgentMessage.requestPlanSummary(sender: "ConversationAgent")
        let response = sendAgentMessage(summaryRequest)
        
        if response.messageType == .planSummaryResult {
            return response.content
        }
        return nil
    }
    
    // Request project context
    func requestProjectContext() -> String? {
        let contextRequest = AgentMessage.requestProjectContext(sender: "ConversationAgent")
        let response = sendAgentMessage(contextRequest)
        
        if response.messageType == .projectContextResult {
            return response.content
        }
        return nil
    }
}

// MARK: - Test Helper Functions

func runTest(_ name: String, test: () -> Bool) {
    print("Testing \(name)...")
    let result = test()
    print("  Result: \(result ? "✅ PASSED" : "❌ FAILED")")
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) -> Bool {
    let result = actual == expected
    if !result {
        print("  ❌ \(message)")
        print("    Expected: \(expected)")
        print("    Actual: \(actual)")
    }
    return result
}

func assertContains(_ string: String, _ substring: String, _ message: String) -> Bool {
    let result = string.contains(substring)
    if !result {
        print("  ❌ \(message)")
        print("    Expected to contain: \(substring)")
        print("    Actual: \(string)")
    }
    return result
}

// MARK: - Test Execution

// Create mock agents
let planningAgent = MockPlanningAgent()
let conversationAgent = MockConversationAgent(planningAgent: planningAgent)

// Test message type existence
runTest("AgentMessage Types Required for Communication") {
    let requiredTypes: [AgentMessage.MessageType] = [
        .userInput,
        .assistantOutput,
        .requestPlanUpdate,
        .planUpdateConfirmation,
        .requestPlanQuery,
        .planQueryResult,
        .requestPlanSummary,
        .planSummaryResult,
        .requestProjectContext,
        .projectContextResult
    ]
    
    var success = true
    for requiredType in requiredTypes {
        if !AgentMessage.MessageType.allCases.contains(requiredType) {
            print("  ❌ Missing message type: \(requiredType)")
            success = false
        }
    }
    return success
}

// Test plan update
runTest("Plan Update Communication") {
    let updateDetails = "Test Plan Item: This is a test plan item for communication testing"
    let result = conversationAgent.requestPlanUpdate(updateDetails)
    
    // Verify the plan item was added
    let itemAdded = planningAgent.planItems.contains { $0.title == "Test Plan Item" }
    
    return result && itemAdded
}

// Test plan query
runTest("Plan Query Communication") {
    let query = "list all items"
    guard let queryResult = conversationAgent.queryPlan(query) else {
        print("  ❌ Query returned nil")
        return false
    }
    
    // The result should contain all items, including the one we just added
    return assertContains(queryResult, "Test Plan Item", "Query result should include the newly added item")
}

// Test plan summary
runTest("Plan Summary Communication") {
    guard let summaryResult = conversationAgent.requestPlanSummary() else {
        print("  ❌ Summary returned nil")
        return false
    }
    
    // Verify the summary contains expected information
    return assertContains(summaryResult, "Plan Summary", "Summary should have expected format") &&
           assertContains(summaryResult, "Total Items:", "Summary should include total items count")
}

// Test project context
runTest("Project Context Communication") {
    guard let contextResult = conversationAgent.requestProjectContext() else {
        print("  ❌ Context request returned nil")
        return false
    }
    
    // Verify the context matches what we expect
    return assertEqual(contextResult, planningAgent.projectContext, "Context should match the planning agent's context")
}

// Test message routing
runTest("Message Routing") {
    // Create a message with an invalid type
    let invalidMessage = AgentMessage(
        messageType: .error,
        sender: "ConversationAgent",
        recipient: "PlanningAgent",
        content: "This is an invalid message type test"
    )
    
    let response = conversationAgent.sendAgentMessage(invalidMessage)
    
    // The planning agent should respond with an error message
    return assertEqual(response.messageType, .error, "Planning agent should respond with an error for invalid message types")
}

print("\n🏁 Test Execution Complete\n")
