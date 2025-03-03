//
//  NodeInstaller.swift
//  SpeechToCode
//
//  Created on: 2025-03-03
//

import Foundation
import OSLog
import SwiftUI

/// Service responsible for installing Node.js
class NodeInstaller: ObservableObject {
    /// Current installation status
    @Published var status: InstallationStatus = .notStarted
    
    /// Current installation message
    @Published var message: String = "Not started"
    
    /// Current installation progress (0.0 - 1.0)
    @Published var progress: Double = 0.0
    
    /// Error message
    @Published var error: String? = nil
    
    /// Node.js version to install
    private let nodeVersion = "18.17.1"
    
    /// Mac architecture
    private var architecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x64"
        #endif
    }
    
    /// Node.js download URL
    private var nodeDownloadURL: URL? {
        let urlString = "https://nodejs.org/dist/v\(nodeVersion)/node-v\(nodeVersion)-darwin-\(architecture).tar.gz"
        return URL(string: urlString)
    }
    
    /// Enumeration to represent installation status
    enum InstallationStatus {
        case notStarted
        case downloading
        case extracting
        case configuring
        case verifying
        case completed
        case failed
    }
    
    /// Install Node.js to the specified directory
    /// - Parameter targetDirectory: Directory to install Node.js to
    /// - Returns: Path to the Node.js executable
    func installNode(to targetDirectory: URL) async -> String? {
        guard let downloadURL = nodeDownloadURL else {
            await updateStatus(status: .failed, message: "Invalid Node.js download URL", error: "Invalid Node.js download URL")
            AppLogger.log(AppLogger.node, level: .error, message: "Invalid Node.js download URL")
            return nil
        }
        
        // Create unique working directory for installation
        guard let workDir = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("node-install-\(UUID().uuidString)") else {
            await updateStatus(status: .failed, message: "Failed to create working directory", error: "Failed to create working directory")
            AppLogger.log(AppLogger.node, level: .error, message: "Failed to create working directory")
            return nil
        }
        
        do {
            try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
            AppLogger.log(AppLogger.node, level: .info, message: "Created temporary working directory: \(workDir.path)")
        } catch {
            await updateStatus(status: .failed, message: "Failed to create working directory: \(error.localizedDescription)", error: error.localizedDescription)
            AppLogger.log(AppLogger.node, level: .error, message: "Failed to create working directory: \(error.localizedDescription)")
            return nil
        }
        
        await updateStatus(status: .downloading, message: "Downloading Node.js v\(nodeVersion)...", progress: 0.1)
        
        // Download Node.js
        do {
            let tarballURL = workDir.appendingPathComponent("node.tar.gz")
            
            AppLogger.log(AppLogger.node, level: .info, message: "Downloading Node.js v\(nodeVersion) from \(downloadURL.absoluteString)")
            
            // Download using URLSession
            let (downloadedFileURL, _) = try await URLSession.shared.download(from: downloadURL)
            try FileManager.default.moveItem(at: downloadedFileURL, to: tarballURL)
            
            AppLogger.log(AppLogger.node, level: .info, message: "Successfully downloaded Node.js to \(tarballURL.path)")
            
            // Verify the file exists
            if !FileManager.default.fileExists(atPath: tarballURL.path) {
                await updateStatus(status: .failed, message: "Downloaded Node.js tarball not found", error: "Downloaded Node.js tarball not found")
                AppLogger.log(AppLogger.node, level: .error, message: "Downloaded Node.js tarball not found at: \(tarballURL.path)")
                return nil
            }
            
            // Remove quarantine attribute from the downloaded file
            let _ = await ProcessRunner.run(
                "xattr",
                arguments: ["-d", "com.apple.quarantine", tarballURL.path]
            )
            
            // We don't need to check the result as it's ok if the file doesn't have the attribute
            AppLogger.log(AppLogger.node, level: .debug, message: "Attempted to remove quarantine attribute from tarball")
            
            await updateStatus(status: .extracting, message: "Extracting Node.js...", progress: 0.3)
            
            // Extract using tar
            let result = await ProcessRunner.run(
                "tar",
                arguments: ["-xzf", tarballURL.path, "-C", workDir.path]
            )
            
            if !result.succeeded {
                await updateStatus(status: .failed, message: "Failed to extract Node.js", error: result.stderr)
                AppLogger.log(AppLogger.node, level: .error, message: "Failed to extract Node.js: \(result.stderr)")
                return nil
            }
            
            // Find the extracted directory
            let nodeDirPrefix = "node-v\(nodeVersion)-darwin-\(architecture)"
            
            let contents = try FileManager.default.contentsOfDirectory(at: workDir, includingPropertiesForKeys: nil)
            guard let extractedDir = contents.first(where: { $0.lastPathComponent.starts(with: nodeDirPrefix) }) else {
                await updateStatus(status: .failed, message: "Could not find extracted Node.js directory", error: "Could not find extracted Node.js directory")
                AppLogger.log(AppLogger.node, level: .error, message: "Could not find extracted Node.js directory. Contents: \(contents.map { $0.lastPathComponent })")
                return nil
            }
            
            await updateStatus(status: .configuring, message: "Installing Node.js...", progress: 0.6)
            AppLogger.log(AppLogger.node, level: .info, message: "Successfully extracted Node.js to \(extractedDir.path)")
            
            // Create target directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: targetDirectory.path) {
                try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
                AppLogger.log(AppLogger.node, level: .debug, message: "Created target directory: \(targetDirectory.path)")
            }
            
            // Install to target directory
            let nodeBinDir = targetDirectory.appendingPathComponent("node-\(nodeVersion)")
            
            // Remove existing installation if it exists
            if FileManager.default.fileExists(atPath: nodeBinDir.path) {
                try FileManager.default.removeItem(at: nodeBinDir)
                AppLogger.log(AppLogger.node, level: .debug, message: "Removed existing Node.js installation: \(nodeBinDir.path)")
            }
            
            AppLogger.log(AppLogger.node, level: .debug, message: "Copying Node.js from \(extractedDir.path) to \(nodeBinDir.path)")
            try FileManager.default.copyItem(at: extractedDir, to: nodeBinDir)
            
            // Verify Node.js executable exists
            let nodePath = nodeBinDir.appendingPathComponent("bin/node").path
            let npmPath = nodeBinDir.appendingPathComponent("bin/npm").path
            
            if !FileManager.default.fileExists(atPath: nodePath) {
                await updateStatus(status: .failed, message: "Node.js executable not found after installation", error: "Node.js executable not found after installation")
                AppLogger.log(AppLogger.node, level: .error, message: "Node.js executable not found at: \(nodePath)")
                return nil
            }
            
            if !FileManager.default.fileExists(atPath: npmPath) {
                await updateStatus(status: .failed, message: "npm executable not found after installation", error: "npm executable not found after installation")
                AppLogger.log(AppLogger.node, level: .error, message: "npm executable not found at: \(npmPath)")
                return nil
            }
            
            // Set executable permissions for bin directory contents
            let binDir = nodeBinDir.appendingPathComponent("bin")
            let recursiveChmodResult = await ProcessRunner.run(
                "chmod",
                arguments: ["-R", "+x", binDir.path]
            )
            
            if !recursiveChmodResult.succeeded {
                AppLogger.log(AppLogger.node, level: .warning, message: "Failed to set executable permissions: \(recursiveChmodResult.stderr)")
            } else {
                AppLogger.log(AppLogger.node, level: .debug, message: "Set executable permissions for bin directory")
            }
            
            // Remove quarantine attribute from all executables
            let removeQuarantineFromBinResult = await ProcessRunner.run(
                "xattr",
                arguments: ["-rd", "com.apple.quarantine", binDir.path]
            )
            
            if !removeQuarantineFromBinResult.succeeded {
                AppLogger.log(AppLogger.node, level: .warning, message: "Failed to remove quarantine attribute: \(removeQuarantineFromBinResult.stderr)")
            } else {
                AppLogger.log(AppLogger.node, level: .debug, message: "Removed quarantine attribute from bin directory")
            }
            
            await updateStatus(status: .verifying, message: "Verifying installation...", progress: 0.9)
            
            // Test Node.js installation
            let versionResult = await ProcessRunner.run(nodePath, arguments: ["--version"])
            if !versionResult.succeeded {
                // Try running with a shell wrapper if direct execution fails
                let shellVersionResult = await ProcessRunner.run(
                    "/bin/bash",
                    arguments: ["-c", nodePath + " --version"]
                )
                
                if !shellVersionResult.succeeded {
                    await updateStatus(status: .failed, message: "Failed to verify Node.js installation", error: versionResult.stderr)
                    AppLogger.log(AppLogger.node, level: .error, message: "Failed to verify Node.js installation: \(versionResult.stderr)")
                    AppLogger.log(AppLogger.node, level: .error, message: "Shell execution also failed: \(shellVersionResult.stderr)")
                    return nil
                } else {
                    AppLogger.log(AppLogger.node, level: .info, message: "Node.js verification succeeded with shell wrapper")
                }
            }
            
            let installedVersion = versionResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            AppLogger.log(AppLogger.node, level: .info, message: "Successfully installed Node.js \(installedVersion) to \(nodeBinDir.path)")
            
            // Clean up temporary directory
            try FileManager.default.removeItem(at: workDir)
            
            await updateStatus(status: .completed, message: "Node.js \(nodeVersion) installed successfully!", progress: 1.0)
            
            return nodePath
            
        } catch {
            await updateStatus(status: .failed, message: "Failed to install Node.js: \(error.localizedDescription)", error: error.localizedDescription)
            AppLogger.log(AppLogger.node, level: .error, message: "Failed to install Node.js: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Update the status
    @MainActor
    private func updateStatus(status: InstallationStatus, message: String, progress: Double = 0.0, error: String? = nil) {
        self.status = status
        self.message = message
        self.progress = progress
        self.error = error
        
        AppLogger.log(AppLogger.node, level: error == nil ? .info : .error, message: "[\(status)] \(message) \(error ?? "")")
    }
    
    /// Returns the common directory where Node.js installations should be stored
    /// This provides a consistent location across app launches
    static func getCommonInstallDirectory() -> URL? {
        do {
            // Use Application Support directory as a consistent location
            let applicationSupportDir = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            // Create a dedicated directory for SpeechToCode
            let appDir = applicationSupportDir.appendingPathComponent("SpeechToCode")
            
            // Create a bin directory for executables
            let binDir = appDir.appendingPathComponent("bin")
            
            // Ensure the directory exists
            if !FileManager.default.fileExists(atPath: binDir.path) {
                try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
                AppLogger.log(AppLogger.node, level: .debug, message: "Created common install directory: \(binDir.path)")
            }
            
            return binDir
        } catch {
            AppLogger.log(AppLogger.node, level: .error, message: "Failed to create common install directory: \(error.localizedDescription)")
            return nil
        }
    }
}
