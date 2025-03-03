import Foundation
import Combine
import OSLog

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
    
    /// Actor to handle mutex operations in an async-safe way
    private actor MutexActor {
        private var isLocked = false
        
        func lock() async {
            while isLocked {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            isLocked = true
        }
        
        func unlock() {
            isLocked = false
        }
    }
    
    /// Mutex actor instance to prevent concurrent npm operations
    private let mutexActor = MutexActor()
    
    /// Delay between npm operations in seconds to avoid "tracker already exists" errors
    private let operationDelay: TimeInterval = 1.5
    
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
        await mutexActor.lock()
        defer {
            // Schedule the lock release after a delay to avoid "tracker already exists" errors
            Task {
                try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
                await mutexActor.unlock()
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
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = nodeDirectory.path + ":" + (env["PATH"] ?? "")
        
        // Execute npm install command with minimal logging
        AppLogger.log(AppLogger.installation, level: .info, message: "Installing npm package: \(packageSpec)")
        
        let result = await ProcessRunner.run(
            npmPath,
            arguments: arguments,
            currentDirectoryPath: workingDirectory?.path,
            environment: env,
            timeout: 60 // 60 second timeout for npm operations
        )
        
        // Check for success
        if result.succeeded {
            AppLogger.log(AppLogger.installation, level: .info, message: "Successfully installed npm package: \(packageSpec)")
            error = nil
            return true
        } else {
            let errorMessage = result.stderr.isEmpty ? "Exit code: \(result.exitCode)" : result.stderr
            error = errorMessage
            AppLogger.log(AppLogger.installation, level: .error, message: "Failed to install npm package: \(packageName). Error: \(errorMessage)")
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
        await mutexActor.lock()
        defer {
            // Schedule the lock release after a delay to avoid "tracker already exists" errors
            Task {
                try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
                await mutexActor.unlock()
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
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = nodeDirectory.path + ":" + (env["PATH"] ?? "")
        
        // Execute npm list command with minimal logging
        AppLogger.log(AppLogger.installation, level: .info, message: "Checking if \(packageName) is installed")
        
        let result = await ProcessRunner.run(
            npmPath,
            arguments: arguments,
            currentDirectoryPath: workingDirectory?.path,
            environment: env,
            timeout: 30
        )
        
        if result.exitCode != 0 && result.exitCode != 1 {
            // npm list can return 1 even on partial success
            let errorMessage = result.stderr.isEmpty ? "Exit code: \(result.exitCode)" : result.stderr
            error = errorMessage
            AppLogger.log(AppLogger.installation, level: .error, message: "Failed to check npm package: \(packageName). Error: \(errorMessage)")
            return PackageCheckResult(installed: false)
        }
        
        // Parse the JSON output to check if package exists and get its version
        guard let jsonData = result.stdout.data(using: .utf8) else {
            error = "Could not parse npm list output"
            return PackageCheckResult(installed: false)
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let dependencies = json["dependencies"] as? [String: Any],
               let packageInfo = dependencies[packageName] as? [String: Any],
               let version = packageInfo["version"] as? String {
                
                AppLogger.log(AppLogger.installation, level: .info, message: "Package \(packageName) is installed (version \(version))")
                return PackageCheckResult(installed: true, version: version)
            } else {
                AppLogger.log(AppLogger.installation, level: .info, message: "Package \(packageName) is not installed")
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
        await mutexActor.lock()
        defer {
            // Schedule the lock release after a delay to avoid "tracker already exists" errors
            Task {
                try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
                await mutexActor.unlock()
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
        
        // Execute npm uninstall command with minimal logging
        AppLogger.log(AppLogger.installation, level: .info, message: "Uninstalling npm package: \(packageName)")
        
        let result = await ProcessRunner.run(
            npmPath,
            arguments: arguments,
            currentDirectoryPath: workingDirectory?.path,
            environment: env,
            timeout: 30
        )
        
        // Check for success
        if result.succeeded {
            AppLogger.log(AppLogger.installation, level: .info, message: "Successfully uninstalled npm package: \(packageName)")
            error = nil
            return true
        } else {
            let errorMessage = result.stderr.isEmpty ? "Exit code: \(result.exitCode)" : result.stderr
            error = errorMessage
            AppLogger.log(AppLogger.installation, level: .error, message: "Failed to uninstall npm package: \(packageName). Error: \(errorMessage)")
            return false
        }
    }
}
