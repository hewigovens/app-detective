@testable import DetectiveCore
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

    @Test("Detects Unity from the bundled player")
    func detectsUnity() throws {
        let app = try FakeApp(frameworks: ["UnityPlayer.dylib"], resources: ["Data"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).stacks == .unity)
    }

    @Test("Detects Unreal Engine from its engine directory")
    func detectsUnreal() throws {
        let app = try FakeApp(contents: ["UE/Engine"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).stacks == .unreal)
    }

    @Test("Detects Compose Multiplatform from Skiko next to the jars")
    func detectsCompose() throws {
        let app = try FakeApp(contents: ["app/libskiko-macos-arm64.dylib", "runtime/Contents/Home"])
        defer { app.remove() }

        let detection = detectService.detect(app.url)
        #expect(detection.stacks == [.compose, .java])
        #expect(detection.matches.map(\.item).contains("libskiko-macos-arm64.dylib"))
    }

    @Test("Detects Avalonia from its native bridge")
    func detectsAvalonia() throws {
        let app = try FakeApp(contents: ["MacOS/libAvaloniaNative.dylib"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).stacks == .avalonia)
    }

    @Test("Detects Xojo from its framework")
    func detectsXojo() throws {
        let app = try FakeApp(frameworks: ["XojoFramework.framework"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).stacks == .xojo)
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
        #expect(await detectService.detectStack(for: otherApp.url) == [.appKit, .objectiveC])
    }

    @Test("A single weak rule is reported as possible, not detected")
    func weakEvidenceIsOnlyPossible() throws {
        let app = try FakeApp(frameworks: ["MyPythonHelpers.framework"])
        defer { app.remove() }

        let detection = detectService.detect(app.url)
        #expect(detection.stacks == [.appKit, .objectiveC])
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

        #expect(await detectService.detectStack(for: app.url) == [.appKit, .objectiveC])
    }

    @Test("AppKit apps report Swift when the executable links the Swift runtime")
    func appKitReportsLanguage() throws {
        let app = try FakeApp(contents: ["SwiftMarker", "ElectronMarker"])
        defer { app.remove() }
        let swiftRule = StackSignature(.swift, [.strong(.file("Contents/SwiftMarker"))])
        let electronRule = StackSignature(.electron, [.strong(.file("Contents/ElectronMarker"))])

        #expect(DetectService(signatures: [swiftRule]).detect(app.url).stacks == [.appKit, .swift])
        #expect(DetectService(signatures: []).detect(app.url).stacks == [.appKit, .objectiveC])
        // The language is only reported for plain AppKit apps.
        let detection = DetectService(signatures: [swiftRule, electronRule]).detect(app.url)
        #expect(detection.stacks == .electron)
        #expect(detection.possibleStacks.isEmpty)
    }

    @Test("Finds executable when Info.plist omits CFBundleExecutable")
    func findsExecutableWithoutBundleExecutableKey() async throws {
        // Like Muse.app, whose executable is found only by the bundle name.
        let app = try FakeApp(declaresExecutable: false)
        defer { app.remove() }

        #expect(await detectService.detectStack(for: app.url) == [.appKit, .objectiveC])
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

    @Test("UIKit, like AppKit, is reported only when nothing more specific is found")
    func uiKitIsBaseline() throws {
        let app = try FakeApp(contents: ["UIKitMarker", "SwiftUIMarker"])
        defer { app.remove() }
        let uiKitRule = StackSignature(.uiKit, [.strong(.file("Contents/UIKitMarker"))])
        let swiftUIRule = StackSignature(.swiftUI, [.strong(.file("Contents/SwiftUIMarker"))])

        #expect(DetectService(signatures: [uiKitRule]).detect(app.url).stacks == [.uiKit, .objectiveC])
        #expect(DetectService(signatures: [uiKitRule, swiftUIRule]).detect(app.url).stacks == .swiftUI)
    }

    @Test("Embedded-string rules are skipped once a stack beyond AppKit is found")
    func embeddedStringsSkippedForSwiftUI() throws {
        // The fake executable is /usr/bin/true, whose strings include this version tag.
        let app = try FakeApp(contents: ["SwiftUIMarker"])
        defer { app.remove() }
        let gpuiRule = StackSignature(.gpui, [.strong(.embeddedString("PROGRAM:true"))])
        let swiftUIRule = StackSignature(.swiftUI, [.strong(.file("Contents/SwiftUIMarker"))])

        #expect(DetectService(signatures: [gpuiRule]).detect(app.url).stacks == .gpui)
        let detection = DetectService(signatures: [gpuiRule, swiftUIRule]).detect(app.url)
        #expect(detection.stacks == .swiftUI)
        #expect(detection.possibleStacks.isEmpty)
        #expect(detection.matches.map(\.stack) == [.swiftUI])
    }

    @Test("Rules version changes when the rules change")
    func versionTracksRules() {
        let rules = [StackSignature(.gtk, [.strong(.file("A"))])]
        let changed = [StackSignature(.gtk, [.weak(.file("A"))])]

        #expect(DetectService(signatures: rules).version == DetectService(signatures: rules).version)
        #expect(DetectService(signatures: rules).version != DetectService(signatures: changed).version)
    }

    @Test("ProcessRunner returns nil when a tool exceeds its timeout")
    func processRunnerTimesOut() {
        #expect(ProcessRunner.output(of: "/bin/sleep", arguments: ["5"], timeout: 0.2) == nil)
        #expect(ProcessRunner.output(of: "/bin/echo", arguments: ["hi"]) == "hi\n")
    }
}
