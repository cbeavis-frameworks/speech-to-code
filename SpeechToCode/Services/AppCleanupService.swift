//
//  AppCleanupService.swift
//  SpeechToCode
//
//  Created on: 2025-03-03
//

import Foundation
import SwiftData

/// Service to clean up all application data for development/testing
class AppCleanupService {
    /// Toggle for enabling/disabling cleanup on app launch
    static var cleanOnLaunch = true
    
    /// Shared instance
    static let shared = AppCleanupService()
    
    /// Clean all application data on app launch
    /// - Parameter modelContext: The SwiftData model context
    @MainActor
    func cleanupOnLaunch(modelContext: ModelContext) async {
        guard AppCleanupService.cleanOnLaunch else {
            AppLogger.log(AppLogger.app, level: .debug, message: "App cleanup on launch is disabled")
            return
        }
        
        AppLogger.log(AppLogger.app, level: .info, message: "🧹 Performing app cleanup on launch")
        
        // 1. Clean the installation directory (removes Node.js and all npm packages)
        do {
            try FileManager.default.cleanInstallationDirectory()
            AppLogger.log(AppLogger.app, level: .info, message: "✓ Cleaned installation directory")
        } catch {
            AppLogger.log(AppLogger.app, level: .error, message: "Failed to clean installation directory: \(error.localizedDescription)")
        }
        
        // 2. Reset all installation state data
        let installationDescriptor = FetchDescriptor<InstallationState>()
        do {
            let installationStates = try modelContext.fetch(installationDescriptor)
            
            for state in installationStates {
                state.reset()
                AppLogger.log(AppLogger.app, level: .debug, message: "Reset installation state")
            }
            
            try modelContext.save()
            AppLogger.log(AppLogger.app, level: .info, message: "✓ Reset all installation states")
        } catch {
            AppLogger.log(AppLogger.app, level: .error, message: "Failed to reset installation states: \(error.localizedDescription)")
        }
        
        // 3. Clear NodePath singleton
        NodePath.shared.clearNodeDetails()
        AppLogger.log(AppLogger.app, level: .info, message: "✓ Cleared NodePath singleton")
        
        // 4. Clear any app preferences if needed
        // Note: Add more cleanup steps as needed in the future
        
        AppLogger.log(AppLogger.app, level: .info, message: "🧹 App cleanup completed. App is in fresh state.")
    }
}
