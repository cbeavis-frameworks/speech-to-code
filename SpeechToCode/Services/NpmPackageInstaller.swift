import Foundation
import Combine

/// Utility class to install, uninstall, and verify npm packages
public class NpmPackageInstaller {
    
    /// Errors that can occur during npm package operations
    public enum NpmError: Error, LocalizedError {
        case npmNotFound
        case packageInstallFailed(String)
        case packageUninstallFailed(String)
        case packageCheckFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .npmNotFound:
                return "npm executable not found"
            case .packageInstallFailed(let message):
                return "Failed to install npm package: \(message)"
            case .packageUninstallFailed(let message):
                return "Failed to uninstall npm package: \(message)"
            case .packageCheckFailed(let message):
                return "Failed to check npm package: \(message)"
            }
        }
    }
    
    /// Result type for checking if a package is installed
    public struct PackageCheckResult {
        public let installed: Bool
        public let version: String?
        
        public init(installed: Bool, version: String? = nil) {
            self.installed = installed
            self.version = version
        }
    }
    
    /// Current status message of the operation
    public let status = CurrentValueSubject<String, Never>("")
    
    /// Last error encountered during operations
    public private(set) var error: String?
    
    /// Lock to prevent concurrent npm operations
    private let npmLock = NSLock()
    
    /// Delay between npm operations in seconds to avoid "tracker already exists" errors
    private let operationDelay: TimeInterval = 1.0
    
    public init() {}
    
    /// Installs an npm package with optional version
    /// - Parameters:
    ///   - packageName: The name of the package to install
    ///   - version: Optional version string (e.g. "1.2.3")
    ///   - global: Whether to install globally (with -g flag)
    ///   - nodeDirectory: Directory where node/npm is installed
    ///   - workingDirectory: Optional directory to run the npm command in
    /// - Returns: Boolean indicating success
    public func installPackage(
        packageName: String,
        version: String? = nil,
        global: Bool = false,
        nodeDirectory: URL,
        workingDirectory: URL? = nil
    ) async -> Bool {
        
        // Acquire lock to prevent concurrent npm operations
        npmLock.lock()
        defer {
            // Schedule the lock release after a delay to avoid "tracker already exists" errors
            Task {
                try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
                npmLock.unlock()
            }
        }
        
        let npmPath = nodeDirectory.appendingPathComponent("npm").path
        
        // Check if npm executable exists
        guard FileManager.default.fileExists(atPath: npmPath) else {
            error = "npm executable not found at \(npmPath)"
            return false
        }
        
        // Prepare installation command
        var packageSpec = packageName
        if let version = version {
            packageSpec = "\(packageName)@\(version)"
        }
        
        // Build command arguments
        var arguments = ["install"]
        if global {
            arguments.append("-g")
        }
        arguments.append(packageSpec)
        
        // Add environment variables
        let pathExtension = "PATH=\(nodeDirectory.path):/usr/local/bin:/usr/bin:/bin"
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = nodeDirectory.path + ":" + (env["PATH"] ?? "")
        
        // Update status
        status.send("Installing \(packageSpec)...")
        
        // Execute npm install command
        let result = await ProcessRunner.run(
            npmPath,
            arguments: arguments,
            currentDirectoryPath: workingDirectory?.path,
            environment: env,
            timeout: 60 // 60 second timeout for npm operations
        )
        
        // Check for success
        if result.exitCode == 0 {
            status.send("Successfully installed \(packageSpec)")
            error = nil
            return true
        } else {
            let errorMessage = result.standardError.isEmpty ? "Exit code: \(result.exitCode)" : result.standardError
            error = errorMessage
            status.send("Failed to install \(packageSpec): \(errorMessage)")
            Logger.shared.error("Failed to install npm package: \(packageName). Error: \(errorMessage)")
            return false
        }
    }
    
    /// Checks if a package is installed and retrieves its version
    /// - Parameters:
    ///   - packageName: The name of the package to check
    ///   - global: Whether to check global installations
    ///   - nodeDirectory: Directory where node/npm is installed
    ///   - workingDirectory: Optional directory to run the npm command in
    /// - Returns: PackageCheckResult containing installed state and version
    public func checkPackageInstalled(
        packageName: String,
        global: Bool = false,
        nodeDirectory: URL,
        workingDirectory: URL? = nil
    ) async -> PackageCheckResult {
        
        // Acquire lock to prevent concurrent npm operations
        npmLock.lock()
        defer {
            // Schedule the lock release after a delay to avoid "tracker already exists" errors
            Task {
                try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
                npmLock.unlock()
            }
        }
        
        let npmPath = nodeDirectory.appendingPathComponent("npm").path
        
        // Check if npm exists
        guard FileManager.default.fileExists(atPath: npmPath) else {
            error = "npm executable not found at \(npmPath)"
            return PackageCheckResult(installed: false)
        }
        
        // Build command arguments for 'npm list'
        var arguments = ["list", "--json", "--depth=0"]
        if global {
            arguments.append("-g")
        }
        
        // Add environment variables
        let pathExtension = "PATH=\(nodeDirectory.path):/usr/local/bin:/usr/bin:/bin"
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = nodeDirectory.path + ":" + (env["PATH"] ?? "")
        
        // Update status
        status.send("Checking if \(packageName) is installed...")
        
        // Execute npm list command
        let result = await ProcessRunner.run(
            npmPath,
            arguments: arguments,
            currentDirectoryPath: workingDirectory?.path,
            environment: env,
            timeout: 30
        )
        
        if result.exitCode != 0 && result.exitCode != 1 {
            // npm list can return 1 even on partial success
            let errorMessage = result.standardError.isEmpty ? "Exit code: \(result.exitCode)" : result.standardError
            error = errorMessage
            status.send("Failed to check if \(packageName) is installed: \(errorMessage)")
            Logger.shared.error("Failed to check npm package: \(packageName). Error: \(errorMessage)")
            return PackageCheckResult(installed: false)
        }
        
        // Parse the JSON output to check if package exists and get its version
        guard let jsonData = result.standardOutput.data(using: .utf8) else {
            error = "Could not parse npm list output"
            return PackageCheckResult(installed: false)
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let dependencies = json["dependencies"] as? [String: Any],
               let packageInfo = dependencies[packageName] as? [String: Any],
               let version = packageInfo["version"] as? String {
                
                status.send("\(packageName) is installed (version \(version))")
                return PackageCheckResult(installed: true, version: version)
            } else {
                status.send("\(packageName) is not installed")
                return PackageCheckResult(installed: false)
            }
        } catch {
            self.error = "Error parsing npm list output: \(error.localizedDescription)"
            return PackageCheckResult(installed: false)
        }
    }
    
    /// Uninstalls an npm package
    /// - Parameters:
    ///   - packageName: The name of the package to uninstall
    ///   - global: Whether to uninstall from global packages
    ///   - nodeDirectory: Directory where node/npm is installed
    ///   - workingDirectory: Optional directory to run the npm command in
    /// - Returns: Boolean indicating success
    public func uninstallPackage(
        packageName: String,
        global: Bool = false,
        nodeDirectory: URL,
        workingDirectory: URL? = nil
    ) async -> Bool {
        
        // Acquire lock to prevent concurrent npm operations
        npmLock.lock()
        defer {
            // Schedule the lock release after a delay to avoid "tracker already exists" errors
            Task {
                try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
                npmLock.unlock()
            }
        }
        
        let npmPath = nodeDirectory.appendingPathComponent("npm").path
        
        // Check if npm exists
        guard FileManager.default.fileExists(atPath: npmPath) else {
            error = "npm executable not found at \(npmPath)"
            return false
        }
        
        // Build uninstall command
        var arguments = ["uninstall"]
        if global {
            arguments.append("-g")
        }
        arguments.append(packageName)
        
        // Add environment variables
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = nodeDirectory.path + ":" + (env["PATH"] ?? "")
        
        // Update status
        status.send("Uninstalling \(packageName)...")
        
        // Execute npm uninstall command
        let result = await ProcessRunner.run(
            npmPath,
            arguments: arguments,
            currentDirectoryPath: workingDirectory?.path,
            environment: env,
            timeout: 30
        )
        
        // Check for success
        if result.exitCode == 0 {
            status.send("Successfully uninstalled \(packageName)")
            error = nil
            return true
        } else {
            let errorMessage = result.standardError.isEmpty ? "Exit code: \(result.exitCode)" : result.standardError
            error = errorMessage
            status.send("Failed to uninstall \(packageName): \(errorMessage)")
            Logger.shared.error("Failed to uninstall npm package: \(packageName). Error: \(errorMessage)")
            return false
        }
    }
}
