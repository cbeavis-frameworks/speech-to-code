import XCTest
import SwiftData
@testable import SpeechToCode

final class NpmPackageInstallerTests: XCTestCase {
    
    private var npmInstaller: NpmPackageInstaller!
    private var nodeDirectory: URL?
    
    override func setUpWithError() throws {
        super.setUp()
        
        npmInstaller = NpmPackageInstaller()
        
        // First try to find Node.js using our app's installation state
        do {
            // Create a model container for reading the installation state
            let modelContainer = try ModelContainer(for: InstallationState.self)
            let modelContext = modelContainer.mainContext
            let descriptor = FetchDescriptor<InstallationState>()
            
            if let installationState = try modelContext.fetch(descriptor).first,
               installationState.nodeInstalled,
               let nodePath = installationState.nodePath {
                // Found Node.js installed by our app
                nodeDirectory = URL(fileURLWithPath: nodePath).deletingLastPathComponent()
                print("Found Node.js from app installation: \(nodeDirectory?.path ?? "unknown")")
                return
            }
        } catch {
            print("Error accessing installation state: \(error.localizedDescription)")
            // Continue to try alternate methods
        }
        
        // If we can't find it from our app, check the homebrew installation
        let homebrewPaths = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node"
        ]
        
        for path in homebrewPaths {
            if FileManager.default.fileExists(atPath: path) {
                nodeDirectory = URL(fileURLWithPath: path).deletingLastPathComponent()
                print("Found Node.js at Homebrew location: \(nodeDirectory?.path ?? "unknown")")
                return
            }
        }
        
        // Check the app's default installation directory
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let supportDir = appSupportDir {
            let appNodePath = supportDir.appendingPathComponent("SpeechToCode/bin/node").path
            if FileManager.default.fileExists(atPath: appNodePath) {
                nodeDirectory = URL(fileURLWithPath: appNodePath).deletingLastPathComponent()
                print("Found Node.js at app's default location: \(nodeDirectory?.path ?? "unknown")")
                return
            }
        }
        
        // As a last resort, try the system path
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
                print("Found Node.js in system PATH: \(nodeDirectory?.path ?? "unknown")")
            } else {
                print("Unable to find Node.js in any location")
            }
        } catch {
            print("Error finding Node.js: \(error.localizedDescription)")
        }
    }
    
    override func tearDownWithError() throws {
        npmInstaller = nil
        nodeDirectory = nil
        super.tearDown()
    }
    
    func testPackageInstallation() async throws {
        guard let nodeDirectory = nodeDirectory else {
            throw XCTSkip("Node.js installation directory not found, skipping test")
        }
        
        // This is a test package that's small and commonly used
        let packageName = "is-odd"
        let version = "3.0.1"
        
        // First ensure the package is not already installed
        let initialCheckResult = await npmInstaller.checkPackageInstalled(
            packageName: packageName,
            nodeDirectory: nodeDirectory
        )
        
        if initialCheckResult.installed {
            // Uninstall it first if it's already there
            let uninstallSuccess = await npmInstaller.uninstallPackage(
                packageName: packageName,
                nodeDirectory: nodeDirectory
            )
            XCTAssertTrue(uninstallSuccess, "Failed to uninstall existing package")
        }
        
        // Now install the package with a specific version
        let installSuccess = await npmInstaller.installPackage(
            packageName: packageName,
            version: version,
            nodeDirectory: nodeDirectory
        )
        
        XCTAssertTrue(installSuccess, "Failed to install package: \(npmInstaller.error ?? "Unknown error")")
        
        // Verify it was installed correctly
        let checkResult = await npmInstaller.checkPackageInstalled(
            packageName: packageName,
            nodeDirectory: nodeDirectory
        )
        
        XCTAssertTrue(checkResult.installed, "Package not found after installation")
        XCTAssertEqual(checkResult.version, version, "Installed version doesn't match requested version")
        
        // Clean up - uninstall the package
        let cleanupSuccess = await npmInstaller.uninstallPackage(
            packageName: packageName,
            nodeDirectory: nodeDirectory
        )
        
        XCTAssertTrue(cleanupSuccess, "Failed to uninstall package during cleanup")
    }
}
