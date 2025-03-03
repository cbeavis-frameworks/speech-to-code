//
//  AppState.swift
//  SpeechToCode
//
//  Created on: 2025-03-03
//

import Foundation
import SwiftData

/// Represents the current state of the application
@Model
final class AppState {
    /// Indicates if this is the first run of the application
    var isFirstRun: Bool
    
    /// Indicates if the installation has been completed
    var installationCompleted: Bool
    
    /// Selected project directory for Claude Code
    var selectedProjectDirectory: String?
    
    /// Selected voice for text-to-speech
    var selectedVoiceIdentifier: String?
    
    /// Speech rate for text-to-speech
    var speechRate: Float
    
    /// Last time the app was used
    var lastUsed: Date
    
    init(
        isFirstRun: Bool = true,
        installationCompleted: Bool = false,
        selectedProjectDirectory: String? = nil,
        selectedVoiceIdentifier: String? = nil,
        speechRate: Float = 0.5,
        lastUsed: Date = Date()
    ) {
        self.isFirstRun = isFirstRun
        self.installationCompleted = installationCompleted
        self.selectedProjectDirectory = selectedProjectDirectory
        self.selectedVoiceIdentifier = selectedVoiceIdentifier
        self.speechRate = speechRate
        self.lastUsed = lastUsed
    }
}
