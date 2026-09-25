import XCTest

final class AppDetectiveUITests: XCTestCase {
    private var scanFolderURL: URL?
    private var protectedFolderURL: URL?

    override func setUpWithError() throws {
        continueAfterFailure = false

        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppDetectiveUITests_\(UUID().uuidString)", isDirectory: true)
        let readableAppURL = folderURL.appendingPathComponent("Readable.app", isDirectory: true)
        let protectedURL = folderURL.appendingPathComponent("Adobe Creative Cloud", isDirectory: true)

        try FileManager.default.createDirectory(at: readableAppURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: protectedURL, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: protectedURL.path)

        scanFolderURL = folderURL
        protectedFolderURL = protectedURL
    }

    override func tearDownWithError() throws {
        if let protectedFolderURL {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: protectedFolderURL.path)
        }

        if let scanFolderURL {
            try? FileManager.default.removeItem(at: scanFolderURL)
        }
    }

    @MainActor
    func testPermissionDeniedFolderDoesNotBlockReadableApps() throws {
        let scanFolderURL = try XCTUnwrap(scanFolderURL)
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState",
            "YES",
            "--scan-folder",
            scanFolderURL.path
        ]

        app.launch()
        app.activate()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), app.debugDescription)

        XCTAssertTrue(app.staticTexts["Readable"].waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.staticTexts["scan-warning-message"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["scan-error-message"].exists, app.debugDescription)
    }

    @MainActor
    func testInspectorShowsSelectedApp() throws {
        let scanFolderURL = try XCTUnwrap(scanFolderURL)
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "--scan-folder", scanFolderURL.path]

        app.launch()
        app.activate()
        XCTAssertTrue(app.staticTexts["Readable"].waitForExistence(timeout: 15), app.debugDescription)

        app.typeKey("i", modifierFlags: [.command, .option])
        XCTAssertTrue(app.staticTexts["No Selection"].waitForExistence(timeout: 5), app.debugDescription)

        app.staticTexts["Readable"].click()
        XCTAssertTrue(app.staticTexts["Bundle ID"].waitForExistence(timeout: 5), app.debugDescription)
        // The temporary folder is reported under /private, so match on the bundle name only.
        let path = app.staticTexts.matching(NSPredicate(format: "value ENDSWITH %@", "/Readable.app")).firstMatch
        XCTAssertTrue(path.exists, app.debugDescription)
    }
}
