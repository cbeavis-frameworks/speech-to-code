//
//  InstallationState.swift
//  SpeechToCode
//
//  Created on: 2025-03-03
//

import Foundation
import SwiftData

/// Represents the installation state of the dependencies
@Model
final class InstallationState {
    /// Indicates if Node.js is installed
    var nodeInstalled: Bool
    
    /// Path to the Node.js binary
    var nodePath: String?
    
    /// Last verification time
    var lastVerified: Date?
    
    /// Installation directory
    var installationDirectory: String?
    
    /// Version information
    var nodeVersion: String?
    
    /// Installation status message
    var statusMessage: String?
    
    init(
        nodeInstalled: Bool = false,
        nodePath: String? = nil,
        lastVerified: Date? = nil,
        installationDirectory: String? = nil,
        nodeVersion: String? = nil,
        statusMessage: String? = nil
    ) {
        self.nodeInstalled = nodeInstalled
        self.nodePath = nodePath
        self.lastVerified = lastVerified
        self.installationDirectory = installationDirectory
        self.nodeVersion = nodeVersion
        self.statusMessage = statusMessage
    }
    
    /// Reset all installation state, used when testing reinstallation
    func reset() {
        nodeInstalled = false
        nodePath = nil
        lastVerified = nil
        statusMessage = "Installation reset"
    }
}
