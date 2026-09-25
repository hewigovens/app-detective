import DetectiveCore
import Foundation
import LSAppCategory
import Testing

struct DetectServiceTests {

    let detectService = DetectService()

    // MARK: - Framework Detection Tests

    @Test("Detects Electron framework")
    func detectsElectron() async throws {
        let app = try FakeApp(frameworks: ["Electron Framework.framework"])
        defer { app.remove() }

        #expect(await detectService.detectStack(for: app.url) == .electron)
    }

    @Test("Detects Flutter framework")
    func detectsFlutter() async throws {
        let app = try FakeApp(frameworks: ["FlutterMacOS.framework"])
        defer { app.remove() }

        #expect(await detectService.detectStack(for: app.url) == .flutter)
    }

    @Test("Detects multiple frameworks")
    func detectsMultipleFrameworks() async throws {
        let app = try FakeApp(frameworks: ["Electron Framework.framework", "FlutterMacOS.framework"])
        defer { app.remove() }

        #expect(await detectService.detectStack(for: app.url) == [.electron, .flutter])
    }

    @Test("Chromium Embedded Framework is not reported as Electron")
    func detectsCEFWithoutElectron() async throws {
        let app = try FakeApp(frameworks: ["Chromium Embedded Framework.framework"])
        defer { app.remove() }

        #expect(await detectService.detectStack(for: app.url) == .cef)
    }

    @Test("Detects React Native bundle in resources")
    func detectsReactNative() async throws {
        let app = try FakeApp(resources: ["main.jsbundle"])
        defer { app.remove() }

        #expect(await detectService.detectStack(for: app.url) == .reactNative)
    }

    // MARK: - Bundle Layout Tests

    @Test("Falls back to AppKit for a plain native executable")
    func fallsBackToAppKit() async throws {
        let app = try FakeApp()
        defer { app.remove() }

        #expect(await detectService.detectStack(for: app.url) == .appKit)
    }

    @Test("Finds executable when Info.plist omits CFBundleExecutable")
    func findsExecutableWithoutBundleExecutableKey() async throws {
        // Matches Muse.app, whose executable is only discoverable by the bundle name.
        let app = try FakeApp(declaresExecutable: false)
        defer { app.remove() }

        #expect(await detectService.detectStack(for: app.url) == .appKit)
    }

    @Test("Returns other for a directory that is not an app bundle")
    func returnsOtherForEmptyDirectory() async throws {
        let directory = try makeTempDirectory().appendingPathComponent("Empty.app")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        #expect(await detectService.detectStack(for: directory) == .other)
    }

    // MARK: - Category Tests

    @Test("Reads category from Info.plist")
    func readsCategoryFromInfoPlist() throws {
        let app = try FakeApp(category: "public.app-category.developer-tools")
        defer { app.remove() }

        #expect(detectService.extractCategory(from: app.url) == .developerTools)
    }

    @Test("Reads category from iTunesMetadata of a wrapped iOS app")
    func readsCategoryFromWrappedMetadata() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let outerURL = root.appendingPathComponent("Wrapped.app")
        let wrapperURL = outerURL.appendingPathComponent("Wrapper")
        let innerURL = wrapperURL.appendingPathComponent("Wrapped.app")
        try FileManager.default.createDirectory(at: innerURL, withIntermediateDirectories: true)
        try writePlist(["CFBundleExecutable": "Wrapped"], to: innerURL.appendingPathComponent("Info.plist"))
        try writePlist(
            ["categories": ["public.app-category.productivity"]],
            to: wrapperURL.appendingPathComponent("iTunesMetadata.plist")
        )

        #expect(detectService.extractCategory(from: outerURL) == .productivity)
        #expect(detectService.extractCategory(from: innerURL) == .productivity)
    }
}

// MARK: - Helpers

/// A minimal macOS app bundle in a temporary directory.
private struct FakeApp {
    let url: URL

    init(
        frameworks: [String] = [],
        resources: [String] = [],
        declaresExecutable: Bool = true,
        category: String? = nil
    ) throws {
        let fileManager = FileManager.default
        let name = "Fake\(UUID().uuidString.prefix(8))"
        url = try makeTempDirectory().appendingPathComponent("\(name).app")

        let contentsURL = url.appendingPathComponent("Contents")
        let macOSURL = contentsURL.appendingPathComponent("MacOS")
        try fileManager.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        // Any Mach-O that links only libSystem stands in for a native executable.
        try fileManager.copyItem(atPath: "/usr/bin/true", toPath: macOSURL.appendingPathComponent(name).path)

        var info: [String: Any] = ["CFBundleIdentifier": "test.\(name)", "CFBundlePackageType": "APPL"]
        if declaresExecutable {
            info["CFBundleExecutable"] = name
        }
        if let category {
            info["LSApplicationCategoryType"] = category
        }
        try writePlist(info, to: contentsURL.appendingPathComponent("Info.plist"))

        for framework in frameworks {
            let frameworkURL = contentsURL.appendingPathComponent("Frameworks").appendingPathComponent(framework)
            try fileManager.createDirectory(at: frameworkURL, withIntermediateDirectories: true)
        }
        for resource in resources {
            let resourcesURL = contentsURL.appendingPathComponent("Resources")
            try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
            fileManager.createFile(atPath: resourcesURL.appendingPathComponent(resource).path, contents: Data())
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

private func makeTempDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("AppDetectiveTests_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writePlist(_ plist: [String: Any], to url: URL) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: url)
}
