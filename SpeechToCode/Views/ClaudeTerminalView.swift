//
//  ClaudeTerminalView.swift
//  SpeechToCode
//
//  Created on: 2025-03-04
//

import SwiftUI

/// A terminal interface for interacting with Claude Code CLI
struct ClaudeTerminalView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var claudeService: ClaudeCodeService
    @EnvironmentObject private var appStateManager: AppStateManager
    
    @State private var userInput: String = ""
    @State private var isInitializing: Bool = true
    
    init(nodeDirectory: String?) {
        _claudeService = StateObject(wrappedValue: ClaudeCodeService(nodeDirectory: nodeDirectory))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Claude Code Terminal")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            // Terminal output
            ScrollViewReader { scrollView in
                ScrollView {
                    VStack(alignment: .leading) {
                        Text(claudeService.terminalOutput)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("outputEnd")
                    }
                }
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
                .onChange(of: claudeService.terminalOutput) {
                    // Auto-scroll to bottom when content changes
                    scrollView.scrollTo("outputEnd", anchor: .bottom)
                }
            }
            
            // User input area
            HStack {
                TextField("Type your message to Claude...", text: $userInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(claudeService.isProcessing)
                
                Button(action: {
                    Task {
                        let message = userInput
                        userInput = ""
                        _ = await claudeService.sendMessage(message)
                    }
                }) {
                    Text("Send")
                        .frame(width: 80)
                }
                .buttonStyle(.borderedProminent)
                .disabled(userInput.isEmpty || claudeService.isProcessing)
            }
            .padding(.horizontal)
            
            // Command buttons
            HStack(spacing: 20) {
                Button(action: {
                    claudeService.clearTerminal()
                }) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    Task {
                        await claudeService.checkClaudeCodeInstallation()
                    }
                }) {
                    Label("Check Installation", systemImage: "checkmark.circle")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Back to Main View")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            Task {
                if isInitializing {
                    _ = await claudeService.checkClaudeCodeInstallation()
                    isInitializing = false
                }
            }
        }
    }
}

struct ClaudeTerminalView_Previews: PreviewProvider {
    static var previews: some View {
        ClaudeTerminalView(nodeDirectory: nil)
            .environmentObject(AppStateManager())
    }
}
