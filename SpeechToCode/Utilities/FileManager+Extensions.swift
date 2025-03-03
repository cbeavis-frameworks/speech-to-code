//
//  FileManager+Extensions.swift
//  SpeechToCode
//
//  Created on: 2025-03-03
//

import Foundation
import OSLog

extension FileManager {
    /// Get application support directory
    func applicationSupportDirectory() throws -> URL {
        let appSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        // Create application-specific directory
        let bundleID = Bundle.main.bundleIdentifier ?? "com.SpeechToCode"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID)
        
        if !FileManager.default.fileExists(atPath: appDirectory.path) {
            try FileManager.default.createDirectory(
                at: appDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        return appDirectory
    }
    
    /// Get the bin directory for our installations
    func binDirectory() throws -> URL {
        let appDirectory = try applicationSupportDirectory()
        let binDirectory = appDirectory.appendingPathComponent("bin")
        
        if !FileManager.default.fileExists(atPath: binDirectory.path) {
            try FileManager.default.createDirectory(
                at: binDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        return binDirectory
    }
    
    /// Clean installation directory to allow testing installation process
    func cleanInstallationDirectory() throws {
        let binDirectory = try binDirectory()
        
        if FileManager.default.fileExists(atPath: binDirectory.path) {
            AppLogger.log(AppLogger.app, level: .info, message: "Cleaning bin directory: \(binDirectory.path)")
            try FileManager.default.removeItem(at: binDirectory)
            try FileManager.default.createDirectory(
                at: binDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    /// Makes a file executable by adding the execute permission
    /// - Parameter path: Path to the file
    /// - Throws: Error if permission change fails
    func makeExecutable(at path: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
        if var permissions = attributes[.posixPermissions] as? UInt16 {
            // Add execute permission for user, group, and others
            permissions |= 0o111
            try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: path.path)
            AppLogger.log(AppLogger.app, level: .debug, message: "Made file executable: \(path.path)")
        } else {
            throw NSError(domain: "FileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not get file permissions"])
        }
    }
    
    /// Check if file exists and is executable
    /// - Parameter path: Path to the file
    /// - Returns: True if file exists and is executable
    func isExecutable(at path: URL) -> Bool {
        return FileManager.default.isExecutableFile(atPath: path.path)
    }
}
