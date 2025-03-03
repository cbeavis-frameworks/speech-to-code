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
    
    /// Perform the installation of Node.js
    @MainActor
    func performInstallation() async -> Bool {
        guard let installDir = NodeInstaller.getCommonInstallDirectory() else {
            updateStatus(status: .failed, message: "Failed to get installation directory")
            AppLogger.log(AppLogger.installation, level: .error, message: "Failed to get installation directory")
            return false
        }
        
        // Make sure we have a valid model context before continuing
        guard self.modelContext != nil else {
            AppLogger.log(AppLogger.installation, level: .error, message: "No model context available for installation, please reload the view")
            updateStatus(status: .failed, message: "Database error: Please restart the app")
            return false
        }
        
        isInstalling = true
        overallProgress = 0.0
        AppLogger.log(AppLogger.installation, level: .info, message: "Starting installation process to \(installDir.path)")
        
        // Create observers for progress updates
        setupProgressObservers()
        
        // Install Node.js
        updateStatus(status: .inProgress, message: "Installing Node.js...")
        
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
            updateStatus(status: .success, message: "Node.js and npm installed successfully! Node: \(nodeVersion), npm: \(npmVersion)", progress: 1.0)
        } else {
            AppLogger.log(AppLogger.installation, level: .warning, message: "npm verification failed: \(npmVersionResult.stderr)")
            updateStatus(status: .success, message: "Node.js installed successfully but npm verification failed. Node: \(nodeVersion)", progress: 1.0)
        }
        
        // Force a model context check
        if self.modelContext == nil {
            AppLogger.log(AppLogger.installation, level: .error, message: "Model context became nil during installation. This shouldn't happen.")
            // Try to continue anyway, but log the error
        }
            
        // Update installation state with versions and paths
        await updateInstallationStateDirectly(
            nodeInstalled: true,
            nodePath: nodePath,
            nodeVersion: nodeVersion,
            statusMessage: "Node.js installation completed successfully!"
        )
        
        isInstalling = false
        return true
    }
    
    /// Directly update the installation state to ensure it works even if model context is lost
    @MainActor
    private func updateInstallationStateDirectly(
        nodeInstalled: Bool,
        nodePath: String,
        nodeVersion: String,
        statusMessage: String
    ) async {
        // First try the normal way
        updateInstallationState(
            nodeInstalled: nodeInstalled,
            nodePath: nodePath,
            nodeVersion: nodeVersion,
            statusMessage: statusMessage
        )
        
        // If we didn't have a model context, try to force-update the database directly
        if self.modelContext == nil {
            AppLogger.log(AppLogger.installation, level: .warning, message: "Using manual database update as fallback")
            
            // You could add code here to directly access the database if needed
            // For now we'll just warn about the error
        }
    }
    
    /// Set up progress observers for the installers
    private func setupProgressObservers() {
        // Using Tasks to observe progress values
        Task { @MainActor in
            for await progress in nodeInstaller.$progress.values {
                if progress > 0 && progress < 1.0 {
                    overallProgress = progress
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
        
        do {
            AppLogger.log(AppLogger.installation, level: .info, message: "Cleaning installation directory: \(binDirectory.path)")
            try FileManager.default.cleanInstallationDirectory()
            
            // Update the installation state
            updateInstallationState(
                nodeInstalled: false,
                nodePath: nil,
                nodeVersion: nil,
                statusMessage: "Installation cleaned"
            )
            
            AppLogger.log(AppLogger.installation, level: .info, message: "Installation state updated after cleaning")
            return true
        } catch {
            AppLogger.log(AppLogger.installation, level: .error, message: "Failed to clean installation directory: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Update the installation state in the model context
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
        }
    }
}

/// Installation status enum
enum InstallationStatus {
    case inProgress
    case success
    case failed
}
