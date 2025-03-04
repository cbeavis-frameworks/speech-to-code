//
//  ContentView.swift
//  SpeechToCode
//
//  Created by Chris Beavis on 03/03/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appStateManager: AppStateManager
    @State private var showClaudeTerminal: Bool = false
    
    var body: some View {
        Group {
            if appStateManager.isFirstRun || !appStateManager.installationCompleted {
                InstallationView()
                    .onDisappear {
                        appStateManager.updateFirstRunStatus(false)
                    }
            } else {
                MainAppView()
                    .environment(\.modelContext, modelContext)
            }
        }
    }
}

/// The main application view after installation is complete
struct MainAppView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appStateManager: AppStateManager
    @State private var isSelectingProject = false
    @State private var selectedDirectory: URL?
    @State private var showClaudeTerminal: Bool = false
    @State private var installationState: InstallationState?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Voice Control for Claude Code")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Project selection area
            VStack(alignment: .leading, spacing: 10) {
                Text("Project Directory")
                    .font(.headline)
                
                HStack {
                    if let projectDir = appStateManager.selectedProjectDirectory {
                        Text(projectDir)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    } else {
                        Text("No project selected")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: { isSelectingProject = true }) {
                        Text("Browse")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color.white.opacity(0.8))
            .cornerRadius(12)
            .shadow(radius: 2)
            
            // Claude Terminal Button
            Button(action: {
                showClaudeTerminal = true
            }) {
                HStack {
                    Image(systemName: "terminal.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                    Text("Open Claude Terminal")
                        .font(.headline)
                }
                .padding()
                .frame(width: 250)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.vertical)
            
            Spacer()
            
            // Placeholder for voice controls - will be implemented later
            VStack {
                Text("Voice Controls")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Placeholder for microphone button
                Button(action: {
                    // Voice recording will be implemented here
                }) {
                    Image(systemName: "mic.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .padding()
                
                Text("Press to start speaking")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Spacer()
        }
        .padding(30)
        .frame(minWidth: 600, minHeight: 500)
        .fileImporter(
            isPresented: $isSelectingProject,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedURL = urls.first else { return }
                
                // Verify we can access this directory
                let canAccess = selectedURL.startAccessingSecurityScopedResource()
                defer {
                    if canAccess {
                        selectedURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                if canAccess {
                    appStateManager.updateSelectedProjectDirectory(selectedURL.path)
                    selectedDirectory = selectedURL
                }
                
            case .failure(let error):
                print("Error selecting directory: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $showClaudeTerminal) {
            let descriptor = FetchDescriptor<InstallationState>()
            let state = try? modelContext.fetch(descriptor).first
            
            // Get the node bin directory path from the nodePath
            let nodeBinPath: String? = {
                if let nodePath = state?.nodePath, !nodePath.isEmpty {
                    // Extract the bin directory from the node executable path
                    return URL(fileURLWithPath: nodePath).deletingLastPathComponent().path
                }
                return nil
            }()
            
            ClaudeTerminalView(nodeBinPath: nodeBinPath)
                .environmentObject(appStateManager)
        }
        .onAppear {
            // Load the installation state
            let descriptor = FetchDescriptor<InstallationState>()
            installationState = try? modelContext.fetch(descriptor).first
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, AppState.self, InstallationState.self], inMemory: true)
        .environmentObject(AppStateManager())
}
