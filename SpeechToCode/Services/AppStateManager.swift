//
//  AppStateManager.swift
//  SpeechToCode
//
//  Created on: 2025-03-03
//

import Foundation
import SwiftUI
import SwiftData

/// Manages the application state
class AppStateManager: ObservableObject {
    /// Installation completed flag
    @Published var installationCompleted: Bool = false
    @Published var isFirstRun: Bool = true
    @Published var selectedProjectDirectory: String?
    
    /// Initialize with model context
    private var modelContext: ModelContext?
    
    /// Load or create app state
    @MainActor
    func loadOrCreateAppState(modelContext: ModelContext) -> AppState {
        self.modelContext = modelContext
        
        let descriptor = FetchDescriptor<AppState>()
        let appStates = try? modelContext.fetch(descriptor)
        
        if let state = appStates?.first {
            // Update published properties
            self.installationCompleted = state.installationCompleted
            self.isFirstRun = state.isFirstRun
            self.selectedProjectDirectory = state.selectedProjectDirectory
            
            // Update last used timestamp
            state.lastUsed = Date()
            try? modelContext.save()
            
            return state
        } else {
            let newState = AppState()
            modelContext.insert(newState)
            
            // Update published properties
            self.installationCompleted = newState.installationCompleted
            self.isFirstRun = newState.isFirstRun
            self.selectedProjectDirectory = newState.selectedProjectDirectory
            
            return newState
        }
    }
    
    /// Update the installation completed status
    @MainActor
    func updateInstallationCompleted(_ completed: Bool) {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<AppState>()
        if let state = try? modelContext.fetch(descriptor).first {
            state.installationCompleted = completed
            self.installationCompleted = completed
            
            try? modelContext.save()
        }
    }
    
    /// Update first run status
    @MainActor
    func updateFirstRunStatus(_ isFirstRun: Bool) {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<AppState>()
        if let state = try? modelContext.fetch(descriptor).first {
            state.isFirstRun = isFirstRun
            self.isFirstRun = isFirstRun
            
            try? modelContext.save()
        }
    }
    
    /// Update selected project directory
    @MainActor
    func updateSelectedProjectDirectory(_ directory: String?) {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<AppState>()
        if let state = try? modelContext.fetch(descriptor).first {
            state.selectedProjectDirectory = directory
            self.selectedProjectDirectory = directory
            
            try? modelContext.save()
        }
    }
    
    /// Update installation status (used by AppCleanupService)
    @MainActor
    func updateInstallationStatus(_ completed: Bool) {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<AppState>()
        if let state = try? modelContext.fetch(descriptor).first {
            state.installationCompleted = completed
            self.installationCompleted = completed
            
            try? modelContext.save()
        }
    }
}
