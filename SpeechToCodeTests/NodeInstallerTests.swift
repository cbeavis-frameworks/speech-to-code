import XCTest
import SwiftData
@testable import SpeechToCode

final class NodeInstallerTests: XCTestCase {
    
    private var nodeInstaller: NodeInstaller!
    private var testDirectory: URL!
    
    override func setUpWithError() throws {
        super.setUp()
        
        // Disable console logging for tests to reduce output noise
        AppLogger.enableConsolePrinting(false)
        
        nodeInstaller = NodeInstaller()
        
        // Create a temporary test directory for Node.js installation
        let tempBaseDir = FileManager.default.temporaryDirectory
        let testDirName = "node-installer-test-\(UUID().uuidString)"
        testDirectory = tempBaseDir.appendingPathComponent(testDirName)
        
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        
        print("📂 Created test directory for Node.js installation: \(testDirectory.path)")
    }
    
    override func tearDownWithError() throws {
        // Clean up test directory after test
        if FileManager.default.fileExists(atPath: testDirectory.path) {
            try FileManager.default.removeItem(at: testDirectory)
            print("🧹 Removed test directory: \(testDirectory.path)")
        }
        
        nodeInstaller = nil
        testDirectory = nil
        
        super.tearDownWithError()
    }
    
    func testDownloadAndInstallNodeJs() async throws {
        // This test downloads and installs Node.js and verifies that
        // the installation directory is saved properly so it can be used by
        // other components of the app
        
        // Skip test if running in CI environment
        guard !isRunningInCI() else {
            throw XCTSkip("Skipping Node.js download test in CI environment")
        }
        
        // This test requires internet connectivity
        guard await hasInternetConnection() else {
            throw XCTSkip("Skipping Node.js download test - no internet connection")
        }
        
        print("🔄 Starting Node.js installation test")
        
        // 1. Test installation
        let nodePath = await nodeInstaller.installNode(to: testDirectory)
        
        // Verify installation succeeded and returned a valid path
        XCTAssertNotNil(nodePath, "Node.js installation failed: \(nodeInstaller.error ?? "Unknown error")")
        
        if let nodePath = nodePath {
            print("✅ Node.js successfully installed at: \(nodePath)")
            
            // 2. Verify node path exists and is executable
            let nodeExists = FileManager.default.fileExists(atPath: nodePath)
            XCTAssertTrue(nodeExists, "Node.js executable not found at expected path")
            
            if nodeExists {
                // 3. Verify node works by checking its version
                let result = await ProcessRunner.run(nodePath, arguments: ["--version"])
                XCTAssertTrue(result.succeeded, "Node.js version check failed: \(result.stderr)")
                XCTAssertFalse(result.stdout.isEmpty, "Node.js version output was empty")
                
                // 4. Now verify we can create and save the InstallationState
                let installationState = InstallationState()
                installationState.nodeInstalled = true
                installationState.nodePath = nodePath
                installationState.installationDirectory = URL(fileURLWithPath: nodePath).deletingLastPathComponent().deletingLastPathComponent().path
                installationState.lastVerified = Date()
                installationState.nodeVersion = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Verify the installation state data is correct
                XCTAssertTrue(installationState.nodeInstalled)
                XCTAssertEqual(installationState.nodePath, nodePath)
                XCTAssertEqual(URL(fileURLWithPath: installationState.installationDirectory ?? "").lastPathComponent, 
                               URL(fileURLWithPath: nodePath).deletingLastPathComponent().deletingLastPathComponent().lastPathComponent)
                
                print("✅ Installation state successfully created and verified")
                
                // 5. Verify npm is also installed
                let npmPath = URL(fileURLWithPath: nodePath).deletingLastPathComponent().appendingPathComponent("npm").path
                let npmExists = FileManager.default.fileExists(atPath: npmPath)
                XCTAssertTrue(npmExists, "npm executable not found at expected path")
                
                if npmExists {
                    let npmResult = await ProcessRunner.run(npmPath, arguments: ["--version"])
                    XCTAssertTrue(npmResult.succeeded, "npm version check failed: \(npmResult.stderr)")
                    XCTAssertFalse(npmResult.stdout.isEmpty, "npm version output was empty")
                    print("✅ npm executable verified: version \(npmResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
        }
    }
    
    private func isRunningInCI() -> Bool {
        // Check common CI environment variables
        return ProcessInfo.processInfo.environment["CI"] != nil ||
               ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil
    }
    
    private func hasInternetConnection() async -> Bool {
        // Simple connectivity test - try to resolve a reliable domain
        do {
            let result = await ProcessRunner.run(
                "/usr/bin/nslookup",
                arguments: ["nodejs.org"]
            )
            return result.succeeded
        } catch {
            print("⚠️ Network connectivity check failed: \(error.localizedDescription)")
            return false
        }
    }
}
