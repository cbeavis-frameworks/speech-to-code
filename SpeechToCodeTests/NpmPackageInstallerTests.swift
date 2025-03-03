import XCTest
@testable import SpeechToCode

final class NpmPackageInstallerTests: XCTestCase {
    
    private var npmInstaller: NpmPackageInstaller!
    private var nodeDirectory: URL!
    
    override func setUpWithError() throws {
        super.setUp()
        
        npmInstaller = NpmPackageInstaller()
        
        // Get the node directory from the installation state or use a mock path for testing
        let modelContext = try ModelContainer(for: InstallationState.self).mainContext
        let descriptor = FetchDescriptor<InstallationState>()
        
        if let installationState = try? modelContext.fetch(descriptor).first,
           let nodePath = installationState.nodePath,
           installationState.nodeInstalled {
            // Use the actual Node.js installation path
            nodeDirectory = URL(fileURLWithPath: nodePath).deletingLastPathComponent()
        } else {
            // For testing, skip actual tests if Node.js isn't installed
            throw XCTSkip("Node.js not installed, skipping npm package installer tests")
        }
    }
    
    override func tearDownWithError() throws {
        npmInstaller = nil
        nodeDirectory = nil
        super.tearDown()
    }
    
    func testPackageInstallation() async throws {
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
