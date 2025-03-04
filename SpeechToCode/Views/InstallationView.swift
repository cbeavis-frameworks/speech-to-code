//
//  InstallationView.swift
//  SpeechToCode
//
//  Created on: 2025-03-03
//

import SwiftUI
import SwiftData

/// View that handles the installation of Node.js
struct InstallationView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appStateManager: AppStateManager
    @StateObject var installationManager = InstallationManager()
    @State private var installationState: InstallationState?
    @State private var isCheckingInstallation = true
    @State private var showTerminal = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "terminal.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text("Voice Control for Code")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("We need to set up Node.js before you can start using voice coding.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if isCheckingInstallation {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                Text("Checking existing installation...")
                    .font(.subheadline)
            } else if installationManager.isInstalling {
                InstallationProgressView(
                    progress: installationManager.overallProgress,
                    message: installationManager.statusMessage,
                    error: nil
                )
            } else if let state = installationState, state.nodeInstalled {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.green)
                    
                    Text("Installation Complete")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Node.js: \(state.nodeVersion ?? "Unknown")")
                        
                        if state.claudeInstalled {
                            Text("Claude: \(state.claudeVersion ?? "Unknown")")
                                .foregroundColor(.green)
                        } else {
                            Text("Claude: Not installed")
                                .foregroundColor(.orange)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    
                    // Next button to proceed to terminal
                    Button(action: {
                        appStateManager.updateInstallationCompleted(true)
                        showTerminal = true
                    }) {
                        Text("Next: Open Claude Terminal")
                            .frame(minWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.vertical)
                    
                    Button(action: {
                        Task {
                            await cleanAndReinstall()
                        }
                    }) {
                        Text("Reinstall Components")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(spacing: 20) {
                    Text("Setup Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Button(action: {
                        Task {
                            let success = await installationManager.performInstallation()
                            if success {
                                // Force a refresh of the installation state
                                await loadInstallationState()
                            }
                        }
                    }) {
                        Text("Install Node.js and Claude")
                            .frame(minWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(installationManager.isInstalling)
                    
                    if let _ = installationState?.statusMessage, 
                       installationState?.nodeInstalled == false {
                        // Error message is hidden
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .padding(40)
        .onAppear {
            Task {
                await loadInstallationState()
                isCheckingInstallation = false
            }
        }
        .sheet(isPresented: $showTerminal) {
            if let state = installationState {
                ClaudeTerminalView(nodeDirectory: state.nodePath)
            } else {
                ClaudeTerminalView(nodeDirectory: nil)
            }
        }
    }
    
    private func loadInstallationState() async {
        await MainActor.run {
            installationState = installationManager.loadOrCreateInstallationState(modelContext: modelContext)
        }
    }
    
    private func cleanAndReinstall() async {
        await MainActor.run {
            isCheckingInstallation = true
        }
        
        let cleaned = await installationManager.cleanInstallation()
        
        if cleaned {
            await loadInstallationState()
            let success = await installationManager.performInstallation()
            if success {
                // Add a brief delay to allow database operations to complete
                try? await Task.sleep(nanoseconds: 500_000_000) // Wait half a second
                
                // Force a refresh of the installation state
                await loadInstallationState()
            }
        }
        
        await MainActor.run {
            isCheckingInstallation = false
        }
    }
}
