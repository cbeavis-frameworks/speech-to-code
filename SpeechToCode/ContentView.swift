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
    
    var body: some View {
        Group {
            if appStateManager.isFirstRun || !appStateManager.installationCompleted {
                InstallationView()
                    .onDisappear {
                        appStateManager.updateFirstRunStatus(false)
                    }
            } else {
                MainAppView()
            }
        }
    }
}

/// The main application view after installation is complete
struct MainAppView: View {
    @EnvironmentObject private var appStateManager: AppStateManager
    @State private var isSelectingProject = false
    @State private var selectedDirectory: URL?
    
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, AppState.self, InstallationState.self], inMemory: true)
        .environmentObject(AppStateManager())
}
