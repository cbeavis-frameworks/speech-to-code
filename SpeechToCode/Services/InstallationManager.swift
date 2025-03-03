//
//  InstallationManager.swift
//  SpeechToCode
//
//  Created on: 2025-03-03
//

import Foundation
import OSLog
import SwiftData
import SwiftUI

/// Manager for coordinating the installation of Node.js
class InstallationManager: ObservableObject {
    /// Current status message
    @Published var statusMessage: String = "Not started"
    
    /// Whether installation is in progress
    @Published var isInstalling: Bool = false
    
    /// Overall installation progress
    @Published var overallProgress: Double = 0.0
    
    /// Node.js installer
    private let nodeInstaller = NodeInstaller()
    
    /// npm Package Installer
    private let npmInstaller = NpmPackageInstaller()
    
    /// Name of the Claude package to install
    private let claudePackageName = "@claude/cli"
    
    /// Model context
    private var modelContext: ModelContext?
    
    /// Initialize with default values
    init() {
        AppLogger.log(AppLogger.installation, level: .info, message: "InstallationManager initialized")
    }
    
    /// Load or create installation state from the model context
    @MainActor
    func loadOrCreateInstallationState(modelContext: ModelContext) -> InstallationState {
        self.modelContext = modelContext
        
        AppLogger.log(AppLogger.installation, level: .debug, message: "Loading installation state from model context")
        
        let descriptor = FetchDescriptor<InstallationState>()
        let installationStates = try? modelContext.fetch(descriptor)
        
        if let state = installationStates?.first {
            AppLogger.log(AppLogger.installation, level: .info, message: "Found existing installation state: Node: \(state.nodeInstalled ? "Installed" : "Not installed")")
            
            // If node is installed, update the NodePath singleton
            if state.nodeInstalled, let nodePath = state.nodePath {
                NodePath.shared.setNodeDetails(path: nodePath, version: state.nodeVersion)
                AppLogger.log(AppLogger.installation, level: .debug, message: "Updated NodePath singleton from existing installation state")
            }
            
            return state
        } else {
            AppLogger.log(AppLogger.installation, level: .info, message: "Creating new installation state")
            let newState = InstallationState()
            modelContext.insert(newState)
            
            // Save the model context after inserting the new state
            do {
                try modelContext.save()
                AppLogger.log(AppLogger.installation, level: .debug, message: "Saved new installation state to model context")
            } catch {
                AppLogger.log(AppLogger.installation, level: .error, message: "Failed to save new installation state: \(error.localizedDescription)")
            }
            
            return newState
        }
    }
    
    /// Directory for installing binaries
    private var binDirectory: URL? {
        try? FileManager.default.applicationSupportDirectory().appendingPathComponent("bin", isDirectory: true)
    }
    
    /// Perform the full installation of Node.js and Claude package
    @MainActor
    func performInstallation() async -> Bool {
        // Check if installation is already running
        guard !isInstalling else {
            AppLogger.log(AppLogger.installation, level: .warning, message: "Installation already in progress")
            return false
        }
        
        isInstalling = true
        overallProgress = 0.0
        
        // Get the installation directory
        guard let installDir = binDirectory else {
            updateStatus(status: .failed, message: "Failed to determine installation directory")
            AppLogger.log(AppLogger.installation, level: .error, message: "Failed to determine installation directory")
            isInstalling = false
            return false
        }
        
        // Create or use existing installation state
        let installationState = loadOrCreateInstallationState(modelContext: modelContext ?? ModelContext())
        
        // Create observers for progress updates
        setupProgressObservers()
        
        // 1. Install Node.js (70% of progress)
        updateStatus(status: .inProgress, message: "Installing Node.js...", progress: 0.0)
        
        guard let nodePath = await nodeInstaller.installNode(to: installDir) else {
            updateStatus(status: .failed, message: "Node.js installation failed: \(nodeInstaller.error ?? "Unknown error")")
            AppLogger.log(AppLogger.installation, level: .error, message: "Node.js installation failed: \(nodeInstaller.error ?? "Unknown error")")
            isInstalling = false
            return false
        }
        
        AppLogger.log(AppLogger.installation, level: .info, message: "Node.js installed successfully at \(nodePath)")
        
        // Get Node.js version
        let nodeVersionResult = await ProcessRunner.run(nodePath, arguments: ["--version"])
        let nodeVersion = nodeVersionResult.succeeded ? 
            nodeVersionResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : 
            "Unknown"
        
        // Run npm -v to verify npm is working
        let npmPath = URL(fileURLWithPath: nodePath).deletingLastPathComponent().appendingPathComponent("npm").path
        
        // Create environment variables for npm with proper PATH
        var npmEnvironment = ProcessInfo.processInfo.environment
        let nodeDir = URL(fileURLWithPath: nodePath).deletingLastPathComponent().path
        // Add node directory to PATH for npm to find node
        npmEnvironment["PATH"] = "\(nodeDir):\(npmEnvironment["PATH"] ?? "")"
        // Explicitly set the NODE variable to the full path
        npmEnvironment["NODE"] = nodePath
        
        let npmVersionResult = await ProcessRunner.run(
            npmPath, 
            arguments: ["-v"],
            environment: npmEnvironment
        )
        
        let npmVersion = npmVersionResult.succeeded ?
            npmVersionResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) :
            "Unknown"
            
        // Log npm version for verification
        if npmVersionResult.succeeded {
            AppLogger.log(AppLogger.installation, level: .info, message: "npm verification successful. Version: \(npmVersion)")
            updateStatus(status: .inProgress, message: "Node.js and npm installed successfully! Node: \(nodeVersion), npm: \(npmVersion)", progress: 0.7)
            
            // Update the installation state for Node.js
            updateInstallationState(
                nodeInstalled: true,
                nodePath: nodePath,
                nodeVersion: nodeVersion
            )
            
            // 2. Install Claude package (remaining 30% of progress)
            updateStatus(status: .inProgress, message: "Installing Claude package...", progress: 0.7)
            
            // Install the Claude package locally
            let nodeBinDir = URL(fileURLWithPath: nodePath).deletingLastPathComponent()
            let claudeInstalled = await npmInstaller.installPackage(
                packageName: claudePackageName, 
                global: false, 
                nodeDirectory: nodeBinDir,
                workingDirectory: binDirectory
            )
            
            if claudeInstalled {
                // Check the installed version
                let claudeCheck = await npmInstaller.checkPackageInstalled(
                    packageName: claudePackageName,
                    global: false,
                    nodeDirectory: nodeBinDir,
                    workingDirectory: binDirectory
                )
                
                let claudeVersion = claudeCheck.version ?? "Unknown"
                
                // Update the installation state for Claude
                updateInstallationState(
                    nodeInstalled: true,
                    nodePath: nodePath,
                    nodeVersion: nodeVersion,
                    claudeInstalled: true,
                    claudeVersion: claudeVersion
                )
                
                updateStatus(status: .success, message: "Installation complete! Node.js \(nodeVersion) and Claude \(claudeVersion) installed successfully!", progress: 1.0)
                AppLogger.log(AppLogger.installation, level: .info, message: "Claude package installed successfully. Version: \(claudeVersion)")
            } else {
                // Update with Node.js success but Claude failure
                updateInstallationState(
                    nodeInstalled: true,
                    nodePath: nodePath,
                    nodeVersion: nodeVersion,
                    claudeInstalled: false,
                    claudeVersion: nil
                )
                
                updateStatus(status: .partialSuccess, message: "Node.js installed successfully but Claude installation failed: \(npmInstaller.error ?? "Unknown error")", progress: 0.7)
                AppLogger.log(AppLogger.installation, level: .error, message: "Claude package installation failed: \(npmInstaller.error ?? "Unknown error")")
            }
        } else {
            AppLogger.log(AppLogger.installation, level: .warning, message: "npm verification failed: \(npmVersionResult.stderr)")
            updateStatus(status: .partialSuccess, message: "Node.js installed successfully but npm verification failed. Node: \(nodeVersion)", progress: 0.7)
            
            // Update the installation state with just Node.js
            updateInstallationState(
                nodeInstalled: true,
                nodePath: nodePath,
                nodeVersion: nodeVersion
            )
        }
        
        isInstalling = false
        return installationState.nodeInstalled
    }
    
    /// Set up progress observers for the installers
    private func setupProgressObservers() {
        // Using Tasks to observe progress values
        Task { @MainActor in
            for await progress in nodeInstaller.$progress.values {
                if isInstalling && progress > 0 && progress < 1.0 {
                    // Node.js installation is 70% of total progress
                    overallProgress = progress * 0.7
                }
            }
        }
        
        // Subscribe to npm installer status messages
        Task { @MainActor in
            for await statusMsg in npmInstaller.status.values {
                if !statusMsg.isEmpty {
                    // Update status message from npm installer
                    statusMessage = statusMsg
                }
            }
        }
    }
    
    /// Clean the installation by removing the bin directory
    @MainActor
    func cleanInstallation() async -> Bool {
        guard let binDirectory = self.binDirectory else {
            AppLogger.log(AppLogger.installation, level: .error, message: "Failed to get bin directory for cleaning")
            return false
        }
        
        guard let modelContext = self.modelContext else {
            AppLogger.log(AppLogger.installation, level: .error, message: "No model context available for cleaning installation")
            return false
        }
        
        do {
            AppLogger.log(AppLogger.installation, level: .info, message: "Cleaning installation directory: \(binDirectory.path)")
            
            // Remove installation directory and its contents
            try FileManager.default.cleanInstallationDirectory()
            
            // Update the installation state
            let descriptor = FetchDescriptor<InstallationState>()
            if let installationState = try modelContext.fetch(descriptor).first {
                // Reset the installation state
                installationState.reset()
                
                // Clear the NodePath singleton
                NodePath.shared.clearNodeDetails()
                
                do {
                    try modelContext.save()
                    AppLogger.log(AppLogger.installation, level: .info, message: "Installation state updated after cleaning")
                    return true
                } catch {
                    AppLogger.log(AppLogger.installation, level: .error, message: "Failed to save installation state after cleaning: \(error.localizedDescription)")
                    return false
                }
            } else {
                AppLogger.log(AppLogger.installation, level: .error, message: "No installation state found in model context")
                return false
            }
        } catch {
            AppLogger.log(AppLogger.installation, level: .error, message: "Failed to clean installation directory: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Update installation state directly with detailed parameters
    @MainActor
    private func updateInstallationState(
        nodeInstalled: Bool,
        nodePath: String?,
        nodeVersion: String?,
        claudeInstalled: Bool = false,
        claudeVersion: String? = nil
    ) {
        guard let modelContext = self.modelContext else {
            AppLogger.log(AppLogger.installation, level: .error, message: "No model context available for updating installation state")
            return
        }
        
        do {
            let descriptor = FetchDescriptor<InstallationState>()
            if let installationState = try modelContext.fetch(descriptor).first {
                // Update state properties
                installationState.nodeInstalled = nodeInstalled
                installationState.nodePath = nodePath
                installationState.nodeVersion = nodeVersion
                installationState.lastVerified = Date()
                
                // Update Claude properties
                installationState.claudeInstalled = claudeInstalled
                installationState.claudeVersion = claudeVersion
                
                if nodeInstalled, let nodePath = nodePath {
                    // Set installation directory to the parent of bin directory
                    installationState.installationDirectory = URL(fileURLWithPath: nodePath)
                        .deletingLastPathComponent() // remove 'node'
                        .deletingLastPathComponent() // remove 'bin'
                        .path
                    
                    // Update NodePath singleton
                    NodePath.shared.setNodeDetails(path: nodePath, version: nodeVersion)
                } else {
                    // Clear NodePath singleton if node is not installed
                    NodePath.shared.clearNodeDetails()
                }
                
                do {
                    try modelContext.save()
                    AppLogger.log(AppLogger.installation, level: .info, message: "Installation state updated: Node: \(nodeInstalled ? "Installed" : "Not installed"), Claude: \(claudeInstalled ? "Installed" : "Not installed")")
                } catch {
                    AppLogger.log(AppLogger.installation, level: .error, message: "Failed to save installation state: \(error.localizedDescription)")
                }
            } else {
                AppLogger.log(AppLogger.installation, level: .error, message: "No installation state found in model context")
            }
        } catch {
            AppLogger.log(AppLogger.installation, level: .error, message: "Failed to fetch installation state: \(error.localizedDescription)")
        }
    }
    
    /// Update installation state in the model context
    @MainActor
    private func updateInstallationState(
        nodeInstalled: Bool? = nil,
        nodePath: String? = nil,
        nodeVersion: String? = nil,
        statusMessage: String? = nil
    ) {
        guard let modelContext = self.modelContext else {
            AppLogger.log(AppLogger.installation, level: .error, message: "No model context available for updating installation state")
            return
        }
        
        // Attempt to reload the model context if needed
        if modelContext.autosaveEnabled == false {
            AppLogger.log(AppLogger.installation, level: .warning, message: "Model context autosave is disabled, enabling it")
            modelContext.autosaveEnabled = true
        }
        
        let descriptor = FetchDescriptor<InstallationState>()
        do {
            guard let state = try modelContext.fetch(descriptor).first else {
                AppLogger.log(AppLogger.installation, level: .error, message: "No installation state found in model context")
                
                // If no state exists, create a new one
                let newState = InstallationState(
                    nodeInstalled: nodeInstalled ?? false,
                    nodePath: nodePath,
                    lastVerified: Date(),
                    installationDirectory: binDirectory?.path,
                    nodeVersion: nodeVersion,
                    statusMessage: statusMessage
                )
                
                modelContext.insert(newState)
                try modelContext.save()
                AppLogger.log(AppLogger.installation, level: .info, message: "Created and saved new installation state")
                return
            }
            
            if let nodeInstalled = nodeInstalled {
                state.nodeInstalled = nodeInstalled
            }
            
            if let nodePath = nodePath {
                state.nodePath = nodePath
            }
            
            if let nodeVersion = nodeVersion {
                state.nodeVersion = nodeVersion
            }
            
            if let statusMessage = statusMessage {
                state.statusMessage = statusMessage
            }
            
            state.lastVerified = Date()
            
            try modelContext.save()
            AppLogger.log(AppLogger.installation, level: .info, message: "Installation state updated and saved")
        } catch {
            AppLogger.log(AppLogger.installation, level: .error, message: "Failed to save installation state: \(error.localizedDescription)")
        }
    }
    
    /// Update status with progress
    private func updateStatus(status: InstallationStatus, message: String, progress: Double = 0.0) {
        statusMessage = message
        overallProgress = progress
        
        // Only log once - avoid duplicate logging
        switch status {
        case .inProgress:
            AppLogger.log(AppLogger.installation, level: .info, message: message)
        case .success:
            AppLogger.log(AppLogger.installation, level: .info, message: "Installation successful: \(message)")
        case .failed:
            AppLogger.log(AppLogger.installation, level: .error, message: "Installation failed: \(message)")
        case .partialSuccess:
            AppLogger.log(AppLogger.installation, level: .warning, message: "Installation partially successful: \(message)")
        }
    }
}

/// Installation status enum
enum InstallationStatus {
    case inProgress
    case success
    case failed
    case partialSuccess
}
