import SwiftUI
import Combine

/// View for displaying the status of the AI agents
struct AgentStatusView: View {
    @ObservedObject var orchestrator: AgentOrchestrator
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Agent Status")
                .font(.headline)
                .padding(.bottom, 2)
            
            agentStatusRow(title: "System",
                          state: getStateDescription(for: orchestrator.state),
                          stateColor: stateColor(for: orchestrator.state))
            
            if let conversationAgent = orchestrator.conversationAgent {
                agentStatusRow(title: "Conversation",
                              state: getStateDescription(for: conversationAgent.state),
                              stateColor: stateColor(for: conversationAgent.state))
            }
            
            if let planningAgent = orchestrator.planningAgent {
                // Instead of casting, use a separate method to handle PlanningAgent state
                agentStatusRow(title: "Planning",
                              state: getPlanningStateDescription(for: planningAgent.state),
                              stateColor: getPlanningStateColor(for: planningAgent.state))
            }
            
            if let workflowManager = orchestrator.workflowManager {
                agentStatusRow(title: "Workflow",
                              state: getStateDescription(for: workflowManager.state),
                              stateColor: stateColor(for: workflowManager.state))
            }
            
            if let contextManager = orchestrator.contextManager {
                agentStatusRow(title: "Context",
                              state: getStateDescription(for: contextManager.state),
                              stateColor: stateColor(for: contextManager.state))
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
        .frame(width: 250)
    }
    
    private func agentStatusRow(title: String, state: String, stateColor: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 8, height: 8)
                
                Text(state)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - State Display Helpers
    
    private func stateColor(for state: AgentOrchestrator.OrchestratorState) -> Color {
        switch state {
        case .initializing:
            return .yellow
        case .ready:
            return .blue
        case .running:
            return .green
        case .paused:
            return .orange
        case .shutdownInProgress:
            return .orange
        case .shutdown:
            return .gray
        case .error:
            return .red
        }
    }
    
    private func stateColor(for state: ConversationAgent.AgentState) -> Color {
        switch state {
        case .idle:
            return .blue
        case .processing, .processingVoice:
            return .green
        case .listeningForVoice:
            return .purple
        case .speaking:
            return .orange
        case .error:
            return .red
        }
    }
    
    private func stateColor(for state: WorkflowManager.WorkflowState) -> Color {
        switch state {
        case .idle:
            return .blue
        case .executing:
            return .green
        case .paused:
            return .orange
        case .completed:
            return .purple
        case .error:
            return .red
        }
    }
    
    private func stateColor(for state: ContextManager.ContextManagerState) -> Color {
        switch state {
        case .initializing:
            return .yellow
        case .ready:
            return .blue
        case .updating:
            return .green
        case .error:
            return .red
        }
    }
    
    private func getPlanningStateColor(for state: PlanningAgent.AgentState) -> Color {
        switch state {
        case .idle:
            return .blue
        case .processing:
            return .green
        case .error:
            return .red
        }
    }
    
    private func getPlanningStateDescription(for state: PlanningAgent.AgentState) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .processing:
            return "Processing"
        case .error:
            return "Error"
        }
    }
    
    // Descriptions for states
    private func getStateDescription(for state: AgentOrchestrator.OrchestratorState) -> String {
        switch state {
        case .initializing:
            return "Initializing"
        case .ready:
            return "Ready"
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        case .shutdownInProgress:
            return "Shutting Down"
        case .shutdown:
            return "Shutdown"
        case .error:
            return "Error"
        }
    }
    
    private func getStateDescription(for state: ConversationAgent.AgentState) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .processing:
            return "Processing"
        case .listeningForVoice:
            return "Listening"
        case .processingVoice:
            return "Processing Voice"
        case .speaking:
            return "Speaking"
        case .error:
            return "Error"
        }
    }
    
    private func getStateDescription(for state: WorkflowManager.WorkflowState) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .executing:
            return "Executing"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        case .error:
            return "Error"
        }
    }
    
    private func getStateDescription(for state: ContextManager.ContextManagerState) -> String {
        switch state {
        case .initializing:
            return "Initializing"
        case .ready:
            return "Ready"
        case .updating:
            return "Updating"
        case .error:
            return "Error"
        }
    }
}

// MARK: - Preview

// Preview provider
struct AgentStatusView_Previews: PreviewProvider {
    static var previews: some View {
        // This is just a mock for preview purposes
        let mockOrchestrator = MockAgentOrchestrator()
        
        return AgentStatusView(orchestrator: mockOrchestrator)
            .frame(width: 300, height: 200)
            .previewLayout(.sizeThatFits)
    }
    
    // Mock class only for preview purposes
    private class MockAgentOrchestrator: AgentOrchestrator, @unchecked Sendable {
        override init() {
            super.init()
            state = .ready
        }
    }
}
