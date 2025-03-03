import XCTest
import SwiftData
@testable import SpeechToCode

final class NpmPackageInstallerTests: XCTestCase {
    
    private var npmInstaller: NpmPackageInstaller!
    private var nodeDirectory: URL?
    
    override func setUpWithError() throws {
        super.setUp()
        
        npmInstaller = NpmPackageInstaller()
        
        // For tests, we'll try to find node in the system path
        let whichNodeResult = try? Process.run(URL(fileURLWithPath: "/usr/bin/which"), arguments: ["node"])
        let outputPipe = Pipe()
        whichNodeResult?.standardOutput = outputPipe
        whichNodeResult?.waitUntilExit()
        
        if let data = try? outputPipe.fileHandleForReading.readToEnd(),
           let nodePath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !nodePath.isEmpty {
            nodeDirectory = URL(fileURLWithPath: nodePath).deletingLastPathComponent()
            print("Found Node.js at: \(nodeDirectory?.path ?? "unknown")")
        } else {
            // Alternatively, check the user's installation state if possible
            print("Unable to find Node.js in system path")
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
