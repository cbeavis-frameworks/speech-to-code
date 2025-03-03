import Foundation
import Combine

/// Service responsible for installing and managing npm packages
class NpmPackageInstaller {
    
    // MARK: - Properties
    
    /// Error string if installation fails
    var error: String?
    
    /// Progress publisher for tracking installation progress
    let progressSubject = CurrentValueSubject<Double, Never>(0.0)
    
    /// Status message publisher
    let statusMessageSubject = CurrentValueSubject<String, Never>("")
    
    /// Whether installation is in progress
    private(set) var isInstalling = false
    
    // Lock to prevent concurrent npm operations
    private let operationLock = NSLock()
    
    // MARK: - Public Methods
    
    /// Install an npm package with the specified version
    /// - Parameters:
    ///   - packageName: The name of the npm package to install
    ///   - version: The version of the package, or nil for latest
    ///   - global: Whether to install the package globally (-g flag)
    ///   - nodeDirectory: The directory where Node.js is installed
    ///   - timeout: Optional timeout in seconds for the installation process
    /// - Returns: Bool indicating success or failure
    func installPackage(
        packageName: String,
        version: String? = nil,
        global: Bool = false,
        nodeDirectory: URL,
        timeout: TimeInterval = 300 // Default 5 minute timeout
    ) async -> Bool {
        guard !packageName.isEmpty else {
            error = "Package name cannot be empty"
            return false
        }
        
        // Clear previous error
        error = nil
        isInstalling = true
        
        // Set up the environment with the proper PATH
        var env = ProcessInfo.processInfo.environment
        let nodeDir = nodeDirectory.path
        env["PATH"] = "\(nodeDir):\(env["PATH"] ?? "")"
        env["NODE"] = "\(nodeDir)/node"
        
        // Update status
        statusMessageSubject.send("Installing \(packageName)...")
        progressSubject.send(0.1)
        
        // Construct the npm command
        let npmPath = nodeDirectory.appendingPathComponent("npm").path
        
        // Build the installation command
        var arguments = ["install"]
        
        // Add global flag if needed
        if global {
            arguments.append("-g")
        }
        
        // Add the package name with version if specified
        if let version = version {
            arguments.append("\(packageName)@\(version)")
        } else {
            arguments.append(packageName)
        }
        
        // Wait for any ongoing npm operations to complete
        operationLock.lock()
        defer { operationLock.unlock() }
        
        // Run the npm install command
        AppLogger.log(AppLogger.installation, level: .info, message: "Installing npm package: \(packageName) \(version ?? "latest")")
        progressSubject.send(0.3)
        
        let result = await ProcessRunner.run(
            npmPath,
            arguments: arguments,
            environment: env,
            timeout: timeout
        )
        
        // Wait a short time before continuing
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
        
        // Update progress
        progressSubject.send(0.8)
        
        if result.succeeded {
            // Verify installation by checking if the package is listed in npm list
            let verifyArguments = ["list", global ? "-g" : "", "--depth=0"]
            let verifyResult = await ProcessRunner.run(
                npmPath,
                arguments: verifyArguments.filter { !$0.isEmpty },
                environment: env
            )
            
            let packageInstalled = verifyResult.stdout.contains(packageName)
            
            if packageInstalled {
                AppLogger.log(AppLogger.installation, level: .info, message: "Successfully installed npm package: \(packageName)")
                statusMessageSubject.send("Successfully installed \(packageName)")
                progressSubject.send(1.0)
                isInstalling = false
                return true
            } else {
                error = "Package installation verification failed"
                AppLogger.log(AppLogger.installation, level: .error, message: "Package verification failed: \(packageName)")
                statusMessageSubject.send("Failed to verify \(packageName) installation")
                progressSubject.send(1.0)
                isInstalling = false
                return false
            }
        } else {
            error = "Failed to install package: \(result.stderr)"
            AppLogger.log(AppLogger.installation, level: .error, message: "Failed to install npm package: \(packageName). Error: \(result.stderr)")
            statusMessageSubject.send("Failed to install \(packageName)")
            progressSubject.send(1.0)
            isInstalling = false
            return false
        }
    }
    
    /// Uninstall an npm package
    /// - Parameters:
    ///   - packageName: The name of the npm package to uninstall
    ///   - global: Whether the package was installed globally (-g flag)
    ///   - nodeDirectory: The directory where Node.js is installed
    /// - Returns: Bool indicating success or failure
    func uninstallPackage(
        packageName: String,
        global: Bool = false,
        nodeDirectory: URL
    ) async -> Bool {
        guard !packageName.isEmpty else {
            error = "Package name cannot be empty"
            return false
        }
        
        // Clear previous error
        error = nil
        isInstalling = true
        
        // Set up the environment with the proper PATH
        var env = ProcessInfo.processInfo.environment
        let nodeDir = nodeDirectory.path
        env["PATH"] = "\(nodeDir):\(env["PATH"] ?? "")"
        env["NODE"] = "\(nodeDir)/node"
        
        // Update status
        statusMessageSubject.send("Uninstalling \(packageName)...")
        progressSubject.send(0.1)
        
        // Construct the npm command
        let npmPath = nodeDirectory.appendingPathComponent("npm").path
        
        // Build the uninstallation command
        var arguments = ["uninstall"]
        
        // Add global flag if needed
        if global {
            arguments.append("-g")
        }
        
        // Add the package name
        arguments.append(packageName)
        
        // Wait for any ongoing npm operations to complete
        operationLock.lock()
        defer { operationLock.unlock() }
        
        // Run the npm uninstall command
        AppLogger.log(AppLogger.installation, level: .info, message: "Uninstalling npm package: \(packageName)")
        progressSubject.send(0.3)
        
        let result = await ProcessRunner.run(
            npmPath,
            arguments: arguments,
            environment: env
        )
        
        // Wait a short time before continuing
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
        
        // Update progress
        progressSubject.send(0.8)
        
        if result.succeeded {
            // Verify uninstallation by checking if the package is no longer listed in npm list
            let verifyArguments = ["list", global ? "-g" : "", "--depth=0"]
            let verifyResult = await ProcessRunner.run(
                npmPath,
                arguments: verifyArguments.filter { !$0.isEmpty },
                environment: env
            )
            
            let packageStillInstalled = verifyResult.stdout.contains(packageName)
            
            if !packageStillInstalled {
                AppLogger.log(AppLogger.installation, level: .info, message: "Successfully uninstalled npm package: \(packageName)")
                statusMessageSubject.send("Successfully uninstalled \(packageName)")
                progressSubject.send(1.0)
                isInstalling = false
                return true
            } else {
                error = "Package uninstallation verification failed"
                AppLogger.log(AppLogger.installation, level: .error, message: "Package verification failed: \(packageName) still appears to be installed")
                statusMessageSubject.send("Failed to verify \(packageName) uninstallation")
                progressSubject.send(1.0)
                isInstalling = false
                return false
            }
        } else {
            error = "Failed to uninstall package: \(result.stderr)"
            AppLogger.log(AppLogger.installation, level: .error, message: "Failed to uninstall npm package: \(packageName). Error: \(result.stderr)")
            statusMessageSubject.send("Failed to uninstall \(packageName)")
            progressSubject.send(1.0)
            isInstalling = false
            return false
        }
    }
    
    /// Check if a package is installed
    /// - Parameters:
    ///   - packageName: The name of the npm package to check
    ///   - global: Whether to check for global installation
    ///   - nodeDirectory: The directory where Node.js is installed
    /// - Returns: Bool indicating if the package is installed, and the version if available
    func checkPackageInstalled(
        packageName: String,
        global: Bool = false,
        nodeDirectory: URL
    ) async -> (installed: Bool, version: String?) {
        // Set up the environment with the proper PATH
        var env = ProcessInfo.processInfo.environment
        let nodeDir = nodeDirectory.path
        env["PATH"] = "\(nodeDir):\(env["PATH"] ?? "")"
        env["NODE"] = "\(nodeDir)/node"
        
        // Construct the npm command
        let npmPath = nodeDirectory.appendingPathComponent("npm").path
        
        // Build the list command
        let arguments = ["list", global ? "-g" : "", "--depth=0"]
        
        // Wait for any ongoing npm operations to complete
        operationLock.lock()
        defer { operationLock.unlock() }
        
        // Run the npm list command
        let result = await ProcessRunner.run(
            npmPath,
            arguments: arguments.filter { !$0.isEmpty },
            environment: env
        )
        
        // Wait a short time before continuing
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
        
        if result.succeeded {
            // Check if the package is in the list output
            if result.stdout.contains(packageName) {
                // Try to extract the version
                let regex = try? NSRegularExpression(pattern: "\(packageName)@([\\d\\.]+)", options: [])
                let nsString = result.stdout as NSString
                let matches = regex?.matches(in: result.stdout, options: [], range: NSRange(location: 0, length: nsString.length))
                
                if let match = matches?.first, match.numberOfRanges > 1 {
                    let versionRange = match.range(at: 1)
                    let version = nsString.substring(with: versionRange)
                    return (true, version)
                }
                
                return (true, nil)
            }
        }
        
        return (false, nil)
    }
}
