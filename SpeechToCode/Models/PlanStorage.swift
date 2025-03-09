import Foundation

/// Protocol defining the required methods for a plan storage system
protocol PlanStorageProtocol {
    /// Save plan items to storage
    /// - Parameter items: The plan items to save
    /// - Throws: Storage-related errors
    func savePlan(items: [PlanningAgent.PlanItem]) throws
    
    /// Load plan items from storage
    /// - Returns: The loaded plan items
    /// - Throws: Storage-related errors
    func loadPlan() throws -> [PlanningAgent.PlanItem]
    
    /// Save project context to storage
    /// - Parameter context: The project context to save
    /// - Throws: Storage-related errors
    func saveProjectContext(context: String) throws
    
    /// Load project context from storage
    /// - Returns: The loaded project context
    /// - Throws: Storage-related errors
    func loadProjectContext() throws -> String
    
    /// Create a backup of the current plan data
    /// - Parameter name: Optional name for the backup
    /// - Returns: Identifier for the backup
    /// - Throws: Backup-related errors
    func createBackup(name: String?) throws -> String
    
    /// Restore plan data from a backup
    /// - Parameter identifier: The backup identifier
    /// - Throws: Restore-related errors
    func restoreFromBackup(identifier: String) throws
    
    /// List available backups
    /// - Returns: List of backup information
    /// - Throws: Storage-related errors
    func listBackups() throws -> [PlanBackupInfo]
    
    /// Delete a backup
    /// - Parameter identifier: The backup identifier
    /// - Throws: Storage-related errors
    func deleteBackup(identifier: String) throws
}

/// Information about a plan backup
struct PlanBackupInfo: Codable, Identifiable {
    /// Unique identifier for the backup
    var id: String
    /// User-provided name for the backup (optional)
    var name: String?
    /// When the backup was created
    var createdAt: Date
    /// Size of the backup in bytes
    var sizeInBytes: Int
    /// Version of the plan format
    var formatVersion: Int
}

/// An error that can occur during plan storage operations
enum PlanStorageError: Error {
    case fileSystemError(String)
    case serializationError(String)
    case backupNotFound(String)
    case incompatibleVersion(String)
    case corruptedData(String)
}

/// Implementation of plan storage using the file system
class FilePlanStorage: PlanStorageProtocol {
    /// Current format version for plan storage
    private let currentFormatVersion = 1
    
    /// Base directory for plan storage
    private let baseDirectory: URL
    /// File for storing plan items
    private let planFile: URL
    /// File for storing project context
    private let contextFile: URL
    /// Directory for storing backups
    private let backupsDirectory: URL
    /// File for storing backup metadata
    private let backupsMetadataFile: URL
    
    /// Metadata about all backups
    private var backupsMetadata: [String: PlanBackupInfo] = [:]
    
    /// Initialize with a specific storage directory
    /// - Parameter directory: Base directory for storage
    init(directory: URL) {
        self.baseDirectory = directory
        self.planFile = directory.appendingPathComponent("plan.json")
        self.contextFile = directory.appendingPathComponent("context.txt")
        self.backupsDirectory = directory.appendingPathComponent("backups")
        self.backupsMetadataFile = directory.appendingPathComponent("backups_metadata.json")
        
        // Create necessary directories
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
        
        // Load backups metadata if it exists
        loadBackupsMetadata()
    }
    
    /// Save plan items to storage
    /// - Parameter items: The plan items to save
    func savePlan(items: [PlanningAgent.PlanItem]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(items)
        try data.write(to: planFile)
    }
    
    /// Load plan items from storage
    /// - Returns: The loaded plan items
    func loadPlan() throws -> [PlanningAgent.PlanItem] {
        guard FileManager.default.fileExists(atPath: planFile.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: planFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([PlanningAgent.PlanItem].self, from: data)
        } catch {
            throw PlanStorageError.serializationError("Failed to decode plan items: \(error.localizedDescription)")
        }
    }
    
    /// Save project context to storage
    /// - Parameter context: The project context to save
    func saveProjectContext(context: String) throws {
        try context.write(to: contextFile, atomically: true, encoding: .utf8)
    }
    
    /// Load project context from storage
    /// - Returns: The loaded project context
    func loadProjectContext() throws -> String {
        guard FileManager.default.fileExists(atPath: contextFile.path) else {
            return ""
        }
        
        do {
            return try String(contentsOf: contextFile, encoding: .utf8)
        } catch {
            throw PlanStorageError.fileSystemError("Failed to read context file: \(error.localizedDescription)")
        }
    }
    
    /// Create a backup of the current plan data
    /// - Parameter name: Optional name for the backup
    /// - Returns: Identifier for the backup
    func createBackup(name: String? = nil) throws -> String {
        // Generate a unique ID for the backup
        let backupId = UUID().uuidString
        let backupDir = backupsDirectory.appendingPathComponent(backupId)
        
        do {
            // Create backup directory
            try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            
            // Copy plan file if it exists
            if FileManager.default.fileExists(atPath: planFile.path) {
                try FileManager.default.copyItem(at: planFile, to: backupDir.appendingPathComponent("plan.json"))
            }
            
            // Copy context file if it exists
            if FileManager.default.fileExists(atPath: contextFile.path) {
                try FileManager.default.copyItem(at: contextFile, to: backupDir.appendingPathComponent("context.txt"))
            }
            
            // Create metadata file with version information
            let metadataFile = backupDir.appendingPathComponent("metadata.json")
            let metadata: [String: Any] = [
                "formatVersion": currentFormatVersion,
                "createdAt": ISO8601DateFormatter().string(from: Date()),
                "name": name ?? "Backup \(Date())"
            ]
            
            let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try metadataData.write(to: metadataFile)
            
            // Calculate backup size
            let backupAttributes = try FileManager.default.attributesOfItem(atPath: backupDir.path)
            let backupSize = (backupAttributes[.size] as? NSNumber)?.intValue ?? 0
            
            // Add to backups metadata
            let backupInfo = PlanBackupInfo(
                id: backupId,
                name: name,
                createdAt: Date(),
                sizeInBytes: backupSize,
                formatVersion: currentFormatVersion
            )
            backupsMetadata[backupId] = backupInfo
            try saveBackupsMetadata()
            
            return backupId
        } catch {
            // Clean up if backup failed
            try? FileManager.default.removeItem(at: backupDir)
            throw PlanStorageError.fileSystemError("Failed to create backup: \(error.localizedDescription)")
        }
    }
    
    /// Restore plan data from a backup
    /// - Parameter identifier: The backup identifier
    func restoreFromBackup(identifier: String) throws {
        let backupDir = backupsDirectory.appendingPathComponent(identifier)
        
        // Verify backup exists
        guard FileManager.default.fileExists(atPath: backupDir.path) else {
            throw PlanStorageError.backupNotFound("Backup with ID \(identifier) not found")
        }
        
        // Check version compatibility
        let metadataFile = backupDir.appendingPathComponent("metadata.json")
        guard FileManager.default.fileExists(atPath: metadataFile.path) else {
            throw PlanStorageError.corruptedData("Backup metadata not found")
        }
        
        do {
            let metadataData = try Data(contentsOf: metadataFile)
            let metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
            
            guard let formatVersion = metadata?["formatVersion"] as? Int else {
                throw PlanStorageError.corruptedData("Backup metadata is corrupted")
            }
            
            guard formatVersion <= currentFormatVersion else {
                throw PlanStorageError.incompatibleVersion("Backup format version \(formatVersion) is newer than current version \(currentFormatVersion)")
            }
            
            // Create a backup of current data before restoring
            let tempBackupId = try createBackup(name: "Auto-backup before restore")
            
            // Restore plan file
            let backupPlanFile = backupDir.appendingPathComponent("plan.json")
            if FileManager.default.fileExists(atPath: backupPlanFile.path) {
                if FileManager.default.fileExists(atPath: planFile.path) {
                    try FileManager.default.removeItem(at: planFile)
                }
                try FileManager.default.copyItem(at: backupPlanFile, to: planFile)
            }
            
            // Restore context file
            let backupContextFile = backupDir.appendingPathComponent("context.txt")
            if FileManager.default.fileExists(atPath: backupContextFile.path) {
                if FileManager.default.fileExists(atPath: contextFile.path) {
                    try FileManager.default.removeItem(at: contextFile)
                }
                try FileManager.default.copyItem(at: backupContextFile, to: contextFile)
            }
            
            print("Successfully restored from backup \(identifier). Previous state backed up to \(tempBackupId)")
        } catch let error as PlanStorageError {
            throw error
        } catch {
            throw PlanStorageError.fileSystemError("Failed to restore from backup: \(error.localizedDescription)")
        }
    }
    
    /// List available backups
    /// - Returns: List of backup information
    func listBackups() throws -> [PlanBackupInfo] {
        return Array(backupsMetadata.values).sorted(by: { $0.createdAt > $1.createdAt })
    }
    
    /// Delete a backup
    /// - Parameter identifier: The backup identifier
    func deleteBackup(identifier: String) throws {
        let backupDir = backupsDirectory.appendingPathComponent(identifier)
        
        // Verify backup exists
        guard FileManager.default.fileExists(atPath: backupDir.path) else {
            throw PlanStorageError.backupNotFound("Backup with ID \(identifier) not found")
        }
        
        do {
            // Remove the backup directory
            try FileManager.default.removeItem(at: backupDir)
            
            // Update metadata
            backupsMetadata.removeValue(forKey: identifier)
            try saveBackupsMetadata()
        } catch {
            throw PlanStorageError.fileSystemError("Failed to delete backup: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Load backups metadata from file
    private func loadBackupsMetadata() {
        guard FileManager.default.fileExists(atPath: backupsMetadataFile.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: backupsMetadataFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backups = try decoder.decode([String: PlanBackupInfo].self, from: data)
            self.backupsMetadata = backups
        } catch {
            print("Warning: Failed to load backups metadata: \(error.localizedDescription)")
            // This is non-fatal, we'll just start with an empty metadata dictionary
            self.backupsMetadata = [:]
        }
    }
    
    /// Save backups metadata to file
    private func saveBackupsMetadata() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(backupsMetadata)
        try data.write(to: backupsMetadataFile)
    }
}
