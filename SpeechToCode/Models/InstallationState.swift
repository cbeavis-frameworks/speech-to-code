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
    
    /// Indicates if Claude package is installed
    var claudeInstalled: Bool
    
    /// Claude package version
    var claudeVersion: String?
    
    /// Path to the Claude package directory
    var claudePackagePath: String?
    
    /// Installation status message
    var statusMessage: String?
    
    init(
        nodeInstalled: Bool = false,
        nodePath: String? = nil,
        lastVerified: Date? = nil,
        installationDirectory: String? = nil,
        nodeVersion: String? = nil,
        claudeInstalled: Bool = false,
        claudeVersion: String? = nil,
        claudePackagePath: String? = nil,
        statusMessage: String? = nil
    ) {
        self.nodeInstalled = nodeInstalled
        self.nodePath = nodePath
        self.lastVerified = lastVerified
        self.installationDirectory = installationDirectory
        self.nodeVersion = nodeVersion
        self.claudeInstalled = claudeInstalled
        self.claudeVersion = claudeVersion
        self.claudePackagePath = claudePackagePath
        self.statusMessage = statusMessage
    }
    
    /// Reset all installation state, used when testing reinstallation
    func reset() {
        nodeInstalled = false
        nodePath = nil
        lastVerified = nil
        claudeInstalled = false
        claudeVersion = nil
        claudePackagePath = nil
        statusMessage = "Installation reset"
    }
}
