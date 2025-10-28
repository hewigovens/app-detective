import Testing
import Foundation

@testable import AppDetective

struct DetectServiceTests {

    let detectService = DetectService()

    // MARK: - Framework Detection Tests

    @Test("Detects Electron framework")
    func detectsElectron() async throws {
        // Given
        let tempDir = try createTempDirectory()
        let frameworksDir = tempDir.appendingPathComponent("Frameworks")
        try FileManager.default.createDirectory(at: frameworksDir, withIntermediateDirectories: true)

        // Create Electron framework directory
        let electronFramework = frameworksDir.appendingPathComponent("Electron Framework.framework")
        try FileManager.default.createDirectory(at: electronFramework, withIntermediateDirectories: true)

        // When
        let result = detectService.scanFrameworksDirectory(frameworksPath: frameworksDir.path)

        // Then
        #expect(result.contains(TechStack.electron), "Should detect Electron framework")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Detects Flutter framework")
    func detectsFlutter() async throws {
        // Given
        let tempDir = try createTempDirectory()
        let frameworksDir = tempDir.appendingPathComponent("Frameworks")
        try FileManager.default.createDirectory(at: frameworksDir, withIntermediateDirectories: true)

        // Create Flutter framework directory
        let flutterFramework = frameworksDir.appendingPathComponent("FlutterMacOS.framework")
        try FileManager.default.createDirectory(at: flutterFramework, withIntermediateDirectories: true)

        // When
        let result = detectService.scanFrameworksDirectory(frameworksPath: frameworksDir.path)

        // Then
        #expect(result.contains(TechStack.flutter), "Should detect Flutter framework")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Detects multiple frameworks")
    func detectsMultipleFrameworks() async throws {
        // Given
        let tempDir = try createTempDirectory()
        let frameworksDir = tempDir.appendingPathComponent("Frameworks")
        try FileManager.default.createDirectory(at: frameworksDir, withIntermediateDirectories: true)

        // Create multiple framework directories
        let electronFramework = frameworksDir.appendingPathComponent("Electron Framework.framework")
        let flutterFramework = frameworksDir.appendingPathComponent("FlutterMacOS.framework")
        try FileManager.default.createDirectory(at: electronFramework, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: flutterFramework, withIntermediateDirectories: true)

        // When
        let result = detectService.scanFrameworksDirectory(frameworksPath: frameworksDir.path)

        // Then
        #expect(result.contains(TechStack.electron), "Should detect Electron framework")
        #expect(result.contains(TechStack.flutter), "Should detect Flutter framework")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Returns empty for non-existent directory")
    func returnsEmptyForNonExistentDirectory() async throws {
        // Given
        let nonExistentPath = "/non/existent/frameworks/path"

        // When
        let result = detectService.scanFrameworksDirectory(frameworksPath: nonExistentPath)

        // Then
        #expect(result.isEmpty, "Should return empty set for non-existent directory")
    }

    // MARK: - URL Analysis Tests

    @Test("Analyzes regular app URL")
    func analyzesRegularAppURL() async throws {
        // Given
        let tempDir = try createTempDirectory()
        let appURL = tempDir.appendingPathComponent("TestApp.app")

        // When
        let (resultURL, isWrapped) = detectService.getAppUrlToAnalyze(appURL: appURL)

        // Then
        #expect(resultURL == appURL, "Should return the same URL for regular apps")
        #expect(!isWrapped, "Should not be marked as wrapped bundle")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Analyzes wrapped bundle URL")
    func analyzesWrappedBundleURL() async throws {
        // Given
        let tempDir = try createTempDirectory()
        let appURL = tempDir.appendingPathComponent("TestApp.app")
        let wrappedBundleURL = appURL.appendingPathComponent("WrappedBundle")

        // Create the WrappedBundle directory
        try FileManager.default.createDirectory(at: wrappedBundleURL, withIntermediateDirectories: true)

        // When
        let (resultURL, isWrapped) = detectService.getAppUrlToAnalyze(appURL: appURL)

        // Then
        // Compare resolved paths since getAppUrlToAnalyze resolves symlinks
        #expect(resultURL.path == wrappedBundleURL.resolvingSymlinksInPath().path, "Should return the WrappedBundle URL")
        #expect(isWrapped, "Should be marked as wrapped bundle")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Helper Methods

    private func createTempDirectory() throws -> URL {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AppDetectiveTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
}
