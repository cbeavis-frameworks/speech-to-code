//
//  NodePath.swift
//  SpeechToCode
//
//  Created on: 2025-03-03
//

import Foundation
import OSLog

/// Singleton to store and access Node.js installation paths across the app and tests
class NodePath {
    /// Shared instance
    static let shared = NodePath()
    
    /// Path to the Node.js binary
    private(set) var nodePath: String?
    
    /// Path to the Node.js bin directory
    private(set) var nodeBinDirectory: URL?
    
    /// Node.js version
    private(set) var nodeVersion: String?
    
    /// File URL for persistent storage
    private var storageURL: URL? {
        try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("SpeechToCode/node-path.json")
    }
    
    /// Private initializer for singleton
    private init() {
        loadFromDisk()
    }
    
    /// Set the Node.js installation details
    /// - Parameters:
    ///   - path: Path to the Node.js executable
    ///   - version: Node.js version
    func setNodeDetails(path: String, version: String?) {
        nodePath = path
        nodeVersion = version
        
        // Calculate the bin directory URL from the node path
        if let nodePath = nodePath {
            nodeBinDirectory = URL(fileURLWithPath: nodePath).deletingLastPathComponent()
        }
        
        // Save to disk for persistence
        saveToDisk()
        
        AppLogger.log(AppLogger.node, level: .info, message: "Set Node.js path: \(path), version: \(version ?? "unknown")")
    }
    
    /// Clear the stored Node.js details
    func clearNodeDetails() {
        nodePath = nil
        nodeVersion = nil
        nodeBinDirectory = nil
        
        // Remove from disk
        if let storageURL = storageURL {
            try? FileManager.default.removeItem(at: storageURL)
        }
        
        AppLogger.log(AppLogger.node, level: .info, message: "Cleared Node.js installation details")
    }
    
    /// Convenience method to get the Node.js bin directory
    /// - Returns: URL of the Node.js bin directory if available
    static func getNodeBinDirectory() -> URL? {
        return NodePath.shared.nodeBinDirectory
    }
    
    /// Save the Node.js details to disk
    private func saveToDisk() {
        guard let storageURL = storageURL else {
            AppLogger.log(AppLogger.node, level: .error, message: "Failed to get storage URL for Node.js path")
            return
        }
        
        let nodeDetails: [String: String?] = [
            "nodePath": nodePath,
            "nodeVersion": nodeVersion
        ]
        
        do {
            // Create parent directory if needed
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            // Encode to JSON
            let data = try JSONEncoder().encode(nodeDetails)
            try data.write(to: storageURL)
            
            AppLogger.log(AppLogger.node, level: .debug, message: "Saved Node.js details to disk")
        } catch {
            AppLogger.log(AppLogger.node, level: .error, message: "Failed to save Node.js details: \(error.localizedDescription)")
        }
    }
    
    /// Load the Node.js details from disk
    private func loadFromDisk() {
        guard let storageURL = storageURL,
              FileManager.default.fileExists(atPath: storageURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let nodeDetails = try JSONDecoder().decode([String: String?].self, from: data)
            
            nodePath = nodeDetails["nodePath"] as? String
            nodeVersion = nodeDetails["nodeVersion"] as? String
            
            // Calculate the bin directory URL from the node path
            if let nodePath = nodePath {
                nodeBinDirectory = URL(fileURLWithPath: nodePath).deletingLastPathComponent()
                AppLogger.log(AppLogger.node, level: .info, message: "Loaded Node.js path from disk: \(nodePath)")
            }
        } catch {
            AppLogger.log(AppLogger.node, level: .error, message: "Failed to load Node.js details: \(error.localizedDescription)")
        }
    }
}
