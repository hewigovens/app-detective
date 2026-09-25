import DetectiveCore
import Foundation
import LSAppCategory
import Testing

struct DetectServiceTests {
    let detectService = DetectService()

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

    @Test("Detects Electron from app.asar when the framework is renamed")
    func detectsElectronFromAsar() async throws {
        let app = try FakeApp(frameworks: ["Codex Framework.framework"], resources: ["app.asar"])
        defer { app.remove() }

        #expect(await detectService.detectStack(for: app.url) == .electron)
    }

    @Test("Detects Xamarin from Contents/MonoBundle")
    func detectsXamarinFromMonoBundle() async throws {
        let app = try FakeApp(contents: ["MonoBundle"])
        defer { app.remove() }

        #expect(await detectService.detectStack(for: app.url) == .xamarin)
    }

    @Test("Qt requires a Qt module name, not any Qt prefix")
    func qtRequiresModuleName() async throws {
        let qtApp = try FakeApp(frameworks: ["QtWidgets.framework"])
        let otherApp = try FakeApp(frameworks: ["Qtum.framework"])
        defer {
            qtApp.remove()
            otherApp.remove()
        }

        #expect(await detectService.detectStack(for: qtApp.url) == .qt)
        #expect(await detectService.detectStack(for: otherApp.url) == .appKit)
    }

    @Test("A single weak rule is reported as possible, not detected")
    func weakEvidenceIsOnlyPossible() throws {
        let app = try FakeApp(frameworks: ["MyPythonHelpers.framework"])
        defer { app.remove() }

        let detection = detectService.detect(app.url)
        #expect(detection.stacks == .appKit)
        #expect(detection.possibleStacks == .python)
        #expect(detection.matches.map(\.item) == ["MyPythonHelpers.framework"])
    }

    @Test("Two weak rules for the same stack are enough to report it")
    func twoWeakRulesAreReported() throws {
        let app = try FakeApp(frameworks: ["React.framework"], resources: ["index.bundle"])
        defer { app.remove() }

        let detection = detectService.detect(app.url)
        #expect(detection.stacks == .reactNative)
        #expect(detection.possibleStacks.isEmpty)
    }

    @Test("Custom signatures can be supplied without changing the catalog")
    func customSignatures() throws {
        let app = try FakeApp(contents: ["Toolkit"])
        defer { app.remove() }

        let service = DetectService(signatures: [StackSignature(.gtk, [.strong(.file("Contents/Toolkit"))])])
        let detection = service.detect(app.url)
        #expect(detection.stacks == .gtk)
        #expect(detection.matches.first?.item == "Contents/Toolkit")
    }

    @Test("Falls back to AppKit for a plain native executable")
    func fallsBackToAppKit() async throws {
        let app = try FakeApp()
        defer { app.remove() }

        #expect(await detectService.detectStack(for: app.url) == .appKit)
    }

    @Test("Finds executable when Info.plist omits CFBundleExecutable")
    func findsExecutableWithoutBundleExecutableKey() async throws {
        // Like Muse.app, whose executable is found only by the bundle name.
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

private struct FakeApp {
    let url: URL

    init(
        frameworks: [String] = [],
        resources: [String] = [],
        contents: [String] = [],
        declaresExecutable: Bool = true,
        category: String? = nil
    ) throws {
        let fileManager = FileManager.default
        let name = "Fake\(UUID().uuidString.prefix(8))"
        url = try makeTempDirectory().appendingPathComponent("\(name).app")

        let contentsURL = url.appendingPathComponent("Contents")
        let macOSURL = contentsURL.appendingPathComponent("MacOS")
        try fileManager.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        // A Mach-O that links only libSystem.
        try fileManager.copyItem(atPath: "/usr/bin/true", toPath: macOSURL.appendingPathComponent(name).path)

        var info: [String: Any] = ["CFBundleIdentifier": "test.\(name)", "CFBundlePackageType": "APPL"]
        if declaresExecutable {
            info["CFBundleExecutable"] = name
        }
        if let category {
            info["LSApplicationCategoryType"] = category
        }
        try writePlist(info, to: contentsURL.appendingPathComponent("Info.plist"))

        // Rules only check existence, so directories suffice.
        let items = frameworks.map { "Frameworks/\($0)" } + resources.map { "Resources/\($0)" } + contents
        for item in items {
            try fileManager.createDirectory(at: contentsURL.appendingPathComponent(item), withIntermediateDirectories: true)
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
