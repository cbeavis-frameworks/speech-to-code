//
//  SpeechToCodeApp.swift
//  SpeechToCode
//
//  Created by Chris Beavis on 03/03/2025.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct SpeechToCodeApp: App {
    @StateObject private var appStateManager = AppStateManager()
    
    init() {
        // Configure logging settings
        #if DEBUG
        // Enable console logging only in debug builds
        AppLogger.enableConsolePrinting(true)
        // Enable automatic cleanup on app launch for development
        AppCleanupService.cleanOnLaunch = true
        #else
        // Disable console logging in release builds
        AppLogger.enableConsolePrinting(false)
        // Disable cleanup in production
        AppCleanupService.cleanOnLaunch = false
        #endif
        
        // Disable verbose context info to reduce log noise
        AppLogger.enableVerboseContext(false)
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            InstallationState.self,
            AppState.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appStateManager)
                .onAppear {
                    // Load app state when the app appears
                    let _ = appStateManager.loadOrCreateAppState(modelContext: sharedModelContainer.mainContext)
                    
                    // Clean up app data on launch if enabled (in debug mode)
                    Task {
                        await AppCleanupService.shared.cleanupOnLaunch(modelContext: sharedModelContainer.mainContext)
                        // Force app to show installation view by updating state
                        appStateManager.updateInstallationStatus(false)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
