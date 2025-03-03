import XCTest
import SwiftData
@testable import SpeechToCode

final class NpmPackageInstallerTests: XCTestCase {
    
    private var npmInstaller: NpmPackageInstaller!
    private var nodeDirectory: URL?
    private var tempDirectory: URL?
    
    override func setUpWithError() throws {
        super.setUp()
        
        // Disable console logging for tests to reduce noise
        AppLogger.enableConsolePrinting(false)
        
        npmInstaller = NpmPackageInstaller()
        
        // Create a temporary directory for npm operations
        let tempBasePath = FileManager.default.temporaryDirectory
        let tempDirName = "npm-test-\(UUID().uuidString)"
        let tempPath = tempBasePath.appendingPathComponent(tempDirName)
        
        try FileManager.default.createDirectory(at: tempPath, withIntermediateDirectories: true)
        tempDirectory = tempPath
        
        // Initialize package.json in the temp directory
        try "{\n  \"name\": \"npm-test\",\n  \"version\": \"1.0.0\"\n}".write(to: tempPath.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        
        // First check NodePath singleton for the installation path
        if let nodeBinDir = NodePath.shared.nodeBinDirectory {
            print("📂 Using Node.js from NodePath singleton: \(nodeBinDir.path)")
            nodeDirectory = nodeBinDir
            return
        }
        
        // Get the Node.js installation directory from the app's InstallationState
        // We'll do this by checking common installation locations since we can't easily
        // access SwiftData in tests without MainActor complications
        
        // Standard app installation directory
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let supportDir = appSupportDir {
            let appNodePath = supportDir.appendingPathComponent("SpeechToCode/bin/node").path
            if FileManager.default.fileExists(atPath: appNodePath) {
                nodeDirectory = URL(fileURLWithPath: appNodePath).deletingLastPathComponent()
                return
            }
        }
        
        // Common Homebrew locations as fallback
        let homebrewPaths = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node"
        ]
        
        for path in homebrewPaths {
            if FileManager.default.fileExists(atPath: path) {
                nodeDirectory = URL(fileURLWithPath: path).deletingLastPathComponent()
                return
            }
        }
        
        // If we still can't find it, check the PATH
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = ["node"]
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            
            try process.run()
            process.waitUntilExit()
            
            if let data = try outputPipe.fileHandleForReading.readToEnd(),
               let nodePath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !nodePath.isEmpty {
                nodeDirectory = URL(fileURLWithPath: nodePath).deletingLastPathComponent()
            } else {
                print("⚠️ Unable to find Node.js in any location")
            }
        } catch {
            print("⚠️ Error finding Node.js: \(error.localizedDescription)")
        }
    }
    
    override func tearDownWithError() throws {
        npmInstaller = nil
        nodeDirectory = nil
        
        // Clean up the temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        
        tempDirectory = nil
        super.tearDown()
    }
    
    func testPackageInstallation() async throws {
        // Ensure we have both Node.js and a temp directory
        guard let nodeDirectory = nodeDirectory else {
            throw XCTSkip("Node.js installation directory not found, skipping test")
        }
        
        guard let tempDirectory = tempDirectory else {
            throw XCTSkip("Temporary directory not created, skipping test")
        }
        
        // Use Claude Code CLI as the test package
        let packageName = "@anthropic-ai/claude-code"
        let version = "0.2.29"
        
        // Try to install with retries
        var installSuccess = false
        var attempts = 0
        let maxAttempts = 3
        
        while !installSuccess && attempts < maxAttempts {
            attempts += 1
            
            // Wait between attempts
            if attempts > 1 {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay between attempts
            }
            
            // Install the package with a specific version
            installSuccess = await npmInstaller.installPackage(
                packageName: packageName,
                version: version,
                nodeDirectory: nodeDirectory,
                workingDirectory: tempDirectory
            )
        }
        
        XCTAssertTrue(installSuccess, "Failed to install package after \(attempts) attempts: \(npmInstaller.error ?? "Unknown error")")
        
        if installSuccess {
            // Verify it was installed correctly
            let checkResult = await npmInstaller.checkPackageInstalled(
                packageName: packageName,
                nodeDirectory: nodeDirectory,
                workingDirectory: tempDirectory
            )
            
            XCTAssertTrue(checkResult.installed, "Package not found after installation")
            XCTAssertEqual(checkResult.version, version, "Installed version doesn't match requested version")
            
            // Clean up - uninstall the package with retries
            var uninstallSuccess = false
            attempts = 0
            
            while !uninstallSuccess && attempts < maxAttempts {
                attempts += 1
                
                // Wait between attempts
                if attempts > 1 {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay between attempts
                }
                
                uninstallSuccess = await npmInstaller.uninstallPackage(
                    packageName: packageName,
                    nodeDirectory: nodeDirectory,
                    workingDirectory: tempDirectory
                )
            }
            
            XCTAssertTrue(uninstallSuccess, "Failed to uninstall package during cleanup after \(attempts) attempts")
        }
    }
}
