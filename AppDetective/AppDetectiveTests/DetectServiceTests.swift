@testable import DetectiveCore
import Foundation
import LSAppCategory
import Testing

struct DetectServiceTests {
    let detectService = DetectService()

    @Test("Detects Electron framework")
    func detectsElectron() throws {
        let app = try FakeApp(frameworks: ["Electron Framework.framework"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).traits == [.electron])
    }

    @Test("Detects Flutter framework")
    func detectsFlutter() throws {
        let app = try FakeApp(frameworks: ["FlutterMacOS.framework"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).traits == [.flutter])
    }

    @Test("Detects multiple UI frameworks")
    func detectsMultipleFrameworks() throws {
        let app = try FakeApp(frameworks: ["Electron Framework.framework", "FlutterMacOS.framework"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).traits == [.electron, .flutter])
    }

    @Test("Chromium Embedded Framework is not reported as Electron")
    func detectsCEFWithoutElectron() throws {
        let app = try FakeApp(frameworks: ["Chromium Embedded Framework.framework"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).traits == [.cef])
    }

    @Test("Detects React Native bundle in resources")
    func detectsReactNative() throws {
        let app = try FakeApp(resources: ["main.jsbundle"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).traits == [.reactNative])
    }

    @Test("Detects Electron from app.asar when the framework is renamed")
    func detectsElectronFromAsar() throws {
        let app = try FakeApp(frameworks: ["Codex Framework.framework"], resources: ["app.asar"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).traits == [.electron])
    }

    @Test("Detects Xamarin from Contents/MonoBundle")
    func detectsXamarinFromMonoBundle() throws {
        let app = try FakeApp(contents: ["MonoBundle"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).traits == [.xamarin])
    }

    @Test("Detects Unity from the bundled player")
    func detectsUnity() throws {
        let app = try FakeApp(frameworks: ["UnityPlayer.dylib"], resources: ["Data"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).traits == [.unity])
    }

    @Test("Detects Unreal Engine from its engine directory")
    func detectsUnreal() throws {
        let app = try FakeApp(contents: ["UE/Engine"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).traits == [.unreal])
    }

    @Test("Detects Compose Multiplatform from Skiko next to the jars")
    func detectsCompose() throws {
        let app = try FakeApp(contents: ["app/libskiko-macos-arm64.dylib", "runtime/Contents/Home"])
        defer { app.remove() }

        let detection = detectService.detect(app.url)
        #expect(detection.traits == [.compose, .java])
        #expect(detection.matches.map(\.item).contains("libskiko-macos-arm64.dylib"))
    }

    @Test("Detects Avalonia from its native bridge")
    func detectsAvalonia() throws {
        let app = try FakeApp(contents: ["MacOS/libAvaloniaNative.dylib"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).traits == [.avalonia])
    }

    @Test("Detects Xojo from its framework")
    func detectsXojo() throws {
        let app = try FakeApp(frameworks: ["XojoFramework.framework"])
        defer { app.remove() }

        #expect(detectService.detect(app.url).traits == [.xojo])
    }

    @Test("Qt requires a Qt module name, not any Qt prefix")
    func qtRequiresModuleName() throws {
        let qtApp = try FakeApp(frameworks: ["QtWidgets.framework"])
        let otherApp = try FakeApp(frameworks: ["Qtum.framework"])
        defer {
            qtApp.remove()
            otherApp.remove()
        }

        #expect(detectService.detect(qtApp.url).traits == [.qt])
        #expect(detectService.detect(otherApp.url).traits == [.appKit, .objectiveC])
    }

    @Test("A single weak rule is reported as possible, not detected")
    func weakEvidenceIsOnlyPossible() throws {
        let app = try FakeApp(frameworks: ["MyPythonHelpers.framework"])
        defer { app.remove() }

        let detection = detectService.detect(app.url)
        #expect(detection.traits == [.appKit, .objectiveC])
        #expect(detection.possibleTraits == [.python])
        #expect(detection.matches.map(\.item) == ["MyPythonHelpers.framework"])
    }

    @Test("Two weak rules for the same trait are enough to report it")
    func twoWeakRulesAreReported() throws {
        let app = try FakeApp(frameworks: ["React.framework"], resources: ["index.bundle"])
        defer { app.remove() }

        let detection = detectService.detect(app.url)
        #expect(detection.traits == [.reactNative])
        #expect(detection.possibleTraits.isEmpty)
    }

    @Test("Custom signatures can be supplied without changing the catalog")
    func customSignatures() throws {
        let app = try FakeApp(contents: ["Toolkit"])
        defer { app.remove() }

        let service = DetectService(signatures: [TraitSignature(.gtk, [.strong(.file("Contents/Toolkit"))])])
        let detection = service.detect(app.url)
        #expect(detection.traits == [.gtk])
        #expect(detection.matches.first?.item == "Contents/Toolkit")
    }

    @Test("Falls back to AppKit for a plain native executable")
    func fallsBackToAppKit() throws {
        let app = try FakeApp()
        defer { app.remove() }

        #expect(detectService.detect(app.url).traits == [.appKit, .objectiveC])
    }

    @Test("Languages are reported next to any UI framework; Objective-C only for native apps")
    func languagesWithAnyFramework() throws {
        let app = try FakeApp(contents: ["SwiftMarker", "ElectronMarker"])
        defer { app.remove() }
        let swiftRule = TraitSignature(.swift, [.strong(.file("Contents/SwiftMarker"))])
        let electronRule = TraitSignature(.electron, [.strong(.file("Contents/ElectronMarker"))])

        #expect(DetectService(signatures: [swiftRule]).detect(app.url).traits == [.appKit, .swift])
        #expect(DetectService(signatures: []).detect(app.url).traits == [.appKit, .objectiveC])
        #expect(DetectService(signatures: [swiftRule, electronRule]).detect(app.url).traits == [.electron, .swift])
        #expect(DetectService(signatures: [electronRule]).detect(app.url).traits == [.electron])
    }

    @Test("A renderer replaces the AppKit fallback and sits beside a toolkit")
    func rendererReplacesAppKitFallback() throws {
        let app = try FakeApp(contents: ["RustMarker", "SwiftMarker", "WgpuMarker", "IcedMarker"])
        defer { app.remove() }
        let rustRule = TraitSignature(.rust, [.strong(.file("Contents/RustMarker"))])
        let swiftRule = TraitSignature(.swift, [.strong(.file("Contents/SwiftMarker"))])
        let wgpuRule = TraitSignature(.wgpu, [.strong(.file("Contents/WgpuMarker"))])
        let icedRule = TraitSignature(.iced, [.strong(.file("Contents/IcedMarker"))])

        #expect(DetectService(signatures: [rustRule]).detect(app.url).traits == [.appKit, .rust])
        #expect(DetectService(signatures: [rustRule, swiftRule]).detect(app.url).traits == [.appKit, .rust, .swift])
        #expect(DetectService(signatures: [rustRule, wgpuRule]).detect(app.url).traits == [.wgpu, .rust])
        #expect(DetectService(signatures: [rustRule, wgpuRule, icedRule]).detect(app.url).traits == [.iced, .rust, .wgpu])
    }

    @Test("Go is reported with AppKit and with Wails")
    func goLanguage() throws {
        let app = try FakeApp(contents: ["GoMarker", "WailsMarker"])
        defer { app.remove() }
        let goRule = TraitSignature(.go, [.strong(.file("Contents/GoMarker"))])
        let wailsRule = TraitSignature(.wails, [.strong(.file("Contents/WailsMarker"))])

        #expect(DetectService(signatures: [goRule]).detect(app.url).traits == [.appKit, .go])
        #expect(DetectService(signatures: [goRule, wailsRule]).detect(app.url).traits == [.wails, .go])
    }

    @Test("Code strings are searched in the app's frameworks and extensions, but not in a UI framework's runtime")
    func codeStringsInBundledBinaries() throws {
        // The fake executable is /usr/bin/true; these binaries are /bin/echo, whose strings include "PROGRAM:echo".
        let app = try FakeApp()
        defer { app.remove() }
        let electronRule = TraitSignature(.electron, [.strong(.framework(.exact("Electron Framework.framework")))])
        let goRule = TraitSignature(.go, [.strong(.codeString("PROGRAM:echo"))])
        try addBundle(at: "Contents/Frameworks/Electron Framework.framework", executable: "Electron Framework", infoPlist: "Resources/Info.plist", to: app)

        #expect(DetectService(signatures: [goRule]).detect(app.url).traits == [.appKit, .go])
        #expect(DetectService(signatures: [electronRule, goRule]).detect(app.url).traits == [.electron])

        try addBundle(at: "Contents/PlugIns/Tunnel.appex", executable: "Contents/MacOS/Tunnel", infoPlist: "Contents/Info.plist", to: app)
        let detection = DetectService(signatures: [electronRule, goRule]).detect(app.url)
        #expect(detection.traits == [.electron, .go])
        #expect(detection.matches.last?.item == "Contents/PlugIns/Tunnel.appex/Contents/MacOS/Tunnel")
    }

    private func addBundle(at path: String, executable: String, infoPlist: String, to app: FakeApp) throws {
        let bundleURL = app.url.appendingPathComponent(path)
        let executableURL = bundleURL.appendingPathComponent(executable)
        let infoURL = bundleURL.appendingPathComponent(infoPlist)
        try FileManager.default.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: infoURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: "/bin/echo", toPath: executableURL.path)
        try writePlist(["CFBundleExecutable": executableURL.lastPathComponent], to: infoURL)
    }

    @Test("Detects updaters next to the UI framework")
    func detectsUpdaters() throws {
        let sparkleApp = try FakeApp(frameworks: ["Sparkle.framework"])
        let electronApp = try FakeApp(frameworks: ["Electron Framework.framework", "Squirrel.framework"])
        defer {
            sparkleApp.remove()
            electronApp.remove()
        }

        #expect(detectService.detect(sparkleApp.url).traits == [.appKit, .objectiveC, .sparkle])
        #expect(detectService.detect(electronApp.url).traits == [.electron, .squirrel])
    }

    @Test("Detects background items, Metal shaders, and a stapled ticket")
    func detectsBundledComponents() throws {
        let app = try FakeApp(
            resources: ["default.metallib"],
            contents: [
                "CodeResources",
                "Library/LoginItems/Helper.app",
                "Library/LaunchAgents/com.example.agent.plist",
                "Library/LaunchDaemons/com.example.daemon.plist",
                "Library/LaunchServices/com.example.helper",
                "Library/LaunchServices/.DS_Store",
                "Library/SystemExtensions/com.example.tunnel.systemextension",
            ]
        )
        defer { app.remove() }

        let expected: Set<DetectiveCore.Trait> = [
            .appKit, .objectiveC, .metal, .notarized,
            .loginItem, .launchAgent, .launchDaemon, .privilegedHelper, .systemExtension,
        ]
        #expect(detectService.detect(app.url).traits == expected)
    }

    @Test("Reads distribution and security from the code signature")
    func readsCodeSignature() throws {
        let app = try FakeApp()
        defer { app.remove() }
        #expect(detectService.detect(app.url).traits == [.appKit, .objectiveC])

        let entitlementsURL = app.url.deletingLastPathComponent().appendingPathComponent("entitlements.plist")
        try writePlist(["com.apple.security.app-sandbox": true], to: entitlementsURL)
        try run("/usr/bin/codesign", ["--sign", "-", "--options", "runtime", "--entitlements", entitlementsURL.path, app.url.path])

        #expect(detectService.detect(app.url).traits == [.appKit, .objectiveC, .adHoc, .sandbox, .hardenedRuntime])
    }

    @Test("An updater doesn't stop embedded-string rules from running")
    func updaterKeepsEmbeddedStrings() throws {
        let app = try FakeApp(frameworks: ["Sparkle.framework"])
        defer { app.remove() }
        let gpuiRule = TraitSignature(.gpui, [.strong(.embeddedString("PROGRAM:true"))])
        let sparkleRule = TraitSignature(.sparkle, [.strong(.framework(.exact("Sparkle.framework")))])

        #expect(DetectService(signatures: [gpuiRule, sparkleRule]).detect(app.url).traits == [.gpui, .sparkle])
    }

    @Test("Finds executable when Info.plist omits CFBundleExecutable")
    func findsExecutableWithoutBundleExecutableKey() throws {
        // Like Muse.app, whose executable is found only by the bundle name.
        let app = try FakeApp(declaresExecutable: false)
        defer { app.remove() }

        #expect(detectService.detect(app.url).traits == [.appKit, .objectiveC])
    }

    @Test("A bundle without an executable is other, keeping what its contents show")
    func otherKeepsBundleContents() throws {
        let directory = try makeTempDirectory().appendingPathComponent("Stub.app")
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent("Contents/Library/LaunchAgents/com.example.agent.plist"),
            withIntermediateDirectories: true
        )
        try writePlist(["CFBundleIdentifier": "test.stub"], to: directory.appendingPathComponent("Contents/Info.plist"))
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        #expect(detectService.detect(directory).traits == [.other, .launchAgent])
    }

    @Test("Returns other for a directory that is not an app bundle")
    func returnsOtherForEmptyDirectory() throws {
        let directory = try makeTempDirectory().appendingPathComponent("Empty.app")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        #expect(detectService.detect(directory).traits == [.other])
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
        let uiKitRule = TraitSignature(.uiKit, [.strong(.file("Contents/UIKitMarker"))])
        let swiftUIRule = TraitSignature(.swiftUI, [.strong(.file("Contents/SwiftUIMarker"))])

        #expect(DetectService(signatures: [uiKitRule]).detect(app.url).traits == [.uiKit, .objectiveC])
        #expect(DetectService(signatures: [uiKitRule, swiftUIRule]).detect(app.url).traits == [.swiftUI])
    }

    @Test("Embedded-string rules are skipped once a UI framework beyond AppKit is found")
    func embeddedStringsSkippedForSwiftUI() throws {
        // The fake executable is /usr/bin/true, whose strings include this version tag.
        let app = try FakeApp(contents: ["SwiftUIMarker"])
        defer { app.remove() }
        let gpuiRule = TraitSignature(.gpui, [.strong(.embeddedString("PROGRAM:true"))])
        let swiftUIRule = TraitSignature(.swiftUI, [.strong(.file("Contents/SwiftUIMarker"))])

        #expect(DetectService(signatures: [gpuiRule]).detect(app.url).traits == [.gpui])
        let detection = DetectService(signatures: [gpuiRule, swiftUIRule]).detect(app.url)
        #expect(detection.traits == [.swiftUI])
        #expect(detection.possibleTraits.isEmpty)
        #expect(detection.matches.map(\.trait) == [.swiftUI])
    }

    @Test("Rules version changes when the rules change")
    func versionTracksRules() {
        let rules = [TraitSignature(.gtk, [.strong(.file("A"))])]
        let changed = [TraitSignature(.gtk, [.weak(.file("A"))])]

        #expect(DetectService(signatures: rules).version == DetectService(signatures: rules).version)
        #expect(DetectService(signatures: rules).version != DetectService(signatures: changed).version)
    }

    @Test("ProcessRunner returns nil when a tool exceeds its timeout")
    func processRunnerTimesOut() {
        #expect(ProcessRunner.output(of: "/bin/sleep", arguments: ["5"], timeout: 0.2) == nil)
        #expect(ProcessRunner.output(of: "/bin/echo", arguments: ["hi"]) == "hi\n")
    }
}
