import Foundation
import LSAppCategory

/// Detects the UI technology stack and category of application bundles.
public final class DetectService: Sendable {
    public init() {}

    // MARK: - Public API

    /// Analyzes an app bundle and returns the tech stacks it is built with.
    ///
    /// Checks run cheapest first: bundled frameworks, bundled resources, linked libraries
    /// (`otool -L`), and finally a `strings` scan of the executable when nothing else matched.
    /// Standard macOS bundles and iOS apps wrapped for Apple silicon Macs are both supported.
    /// - Parameter appURL: URL of the `.app` bundle.
    /// - Returns: The detected stacks, or `.other` if the bundle can't be analyzed.
    public func detectStack(for appURL: URL) async -> TechStack {
        // Bundle resolves the executable the same way LaunchServices does, including bundles
        // without CFBundleExecutable (named after the bundle) and iOS `WrappedBundle` layouts.
        guard let bundle = Bundle(url: appURL) else {
            return .other
        }

        var stacks = Self.frameworkStacks(in: bundle.privateFrameworksURL)
        stacks.formUnion(Self.resourceStacks(in: bundle.resourceURL))

        if let executableURL = bundle.executableURL {
            stacks.formUnion(Self.linkedLibraryStacks(of: executableURL))
            if stacks.isEmpty {
                stacks.formUnion(Self.embeddedStringStacks(of: executableURL))
            }
        } else if stacks.isEmpty {
            return .other
        }

        return Self.resolve(stacks)
    }

    /// Reads the app category from `LSApplicationCategoryType`, falling back to the
    /// App Store metadata that accompanies iOS apps installed on the Mac.
    /// - Parameter appURL: URL of the `.app` bundle.
    /// - Returns: The app category, or `.other` if none is declared.
    public func extractCategory(from appURL: URL) -> AppCategory {
        if let categoryType = Bundle(url: appURL)?.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String {
            return AppCategory(string: categoryType)
        }

        var metadataURLs = [appURL.appendingPathComponent("Wrapper/iTunesMetadata.plist")]
        let parentURL = appURL.deletingLastPathComponent()
        if parentURL.lastPathComponent == "Wrapper" {
            metadataURLs.append(parentURL.appendingPathComponent("iTunesMetadata.plist"))
        }

        for metadataURL in metadataURLs {
            if
                let metadata = NSDictionary(contentsOf: metadataURL),
                let categoryType = (metadata["categories"] as? [String])?.first
            {
                return AppCategory(string: categoryType)
            }
        }

        return .other
    }

    // MARK: - Signatures

    private typealias NameSignature = (stack: TechStack, matches: @Sendable (String) -> Bool)
    private typealias TextSignature = (stack: TechStack, markers: [String])

    /// Matched against item names in the bundle's Frameworks directory.
    private static let frameworkSignatures: [NameSignature] = [
        (.electron, { $0 == "Electron Framework.framework" }),
        (.microsoftEdge, { $0 == "Microsoft Edge Framework.framework" }),
        (.cef, { $0 == "Chromium Embedded Framework.framework" }),
        (.flutter, { $0.contains("Flutter") }),
        (.xamarin, { $0.contains("Xamarin") || $0.contains("Microsoft.Maui") || $0.contains("MonoBundle") }),
        (.python, { $0.hasSuffix(".framework") && $0.lowercased().contains("python") }),
        (.qt, { $0.hasPrefix("Qt") && $0.hasSuffix(".framework") }),
    ]

    /// Matched against the install names of libraries the executable links.
    private static let linkedLibrarySignatures: [TextSignature] = [
        (.swiftUI, ["SwiftUI"]),
        (.catalyst, ["/System/iOSSupport/System/Library/Frameworks/UIKit.framework"]),
        (.appKit, ["/System/Library/Frameworks/Cocoa.framework", "/usr/lib/swift/libswiftAppKit.dylib"]),
        (.electron, ["Electron", "libnode"]),
        (.cef, ["Chromium Embedded Framework", "libcef"]),
        (.python, ["Python", "libpython"]),
        (.qt, ["QtCore", "QtGui"]),
        (.wxWidgets, ["wxWidgets", "libwx_"]),
        (.java, ["libjvm", "JavaVM", "JavaNativeFoundation"]),
        (.xamarin, ["libmono", "libcoreclr", "Microsoft.Maui"]),
        (.flutter, ["Flutter"]),
        (.reactNative, ["React Native", "libjsi", "libhermes"]),
        (.gtk, ["libgtk", "libgdk"]),
    ]

    /// Matched against printable strings in the executable, for stacks that are statically linked.
    private static let embeddedStringSignatures: [TextSignature] = [
        (.java, ["java/lang"]),
        (.gpui, ["gpui::", "/gpui/"]),
        (.tauri, ["tauri"]),
        (.wxWidgets, ["wx_main"]),
        (.iced, ["iced_wgpu"]),
    ]

    // MARK: - Detection Steps

    private static func frameworkStacks(in frameworksURL: URL?) -> TechStack {
        let names = frameworksURL.flatMap { try? FileManager.default.contentsOfDirectory(atPath: $0.path) } ?? []
        var stacks: TechStack = []
        for signature in frameworkSignatures where names.contains(where: signature.matches) {
            stacks.insert(signature.stack)
        }
        return stacks
    }

    private static func resourceStacks(in resourcesURL: URL?) -> TechStack {
        let names = resourcesURL.flatMap { try? FileManager.default.contentsOfDirectory(atPath: $0.path) } ?? []
        let hasJSBundle = names.contains { $0 == "index.bundle" || $0.lowercased().hasSuffix(".jsbundle") }
        return hasJSBundle ? .reactNative : []
    }

    private static func linkedLibraryStacks(of executableURL: URL) -> TechStack {
        guard let output = ProcessRunner.output(of: "/usr/bin/otool", arguments: ["-L", executableURL.path]) else {
            return []
        }
        // Library lines are tab-indented; other lines name the binary itself or its architectures,
        // and matching those would flag apps by their own names (e.g. "Python Launcher").
        let libraries = output
            .split(separator: "\n")
            .filter { $0.hasPrefix("\t") }
            .joined(separator: "\n")
        return match(libraries, against: linkedLibrarySignatures)
    }

    private static func embeddedStringStacks(of executableURL: URL) -> TechStack {
        guard let output = ProcessRunner.output(of: "/usr/bin/strings", arguments: [executableURL.path]) else {
            return []
        }
        return match(output, against: embeddedStringSignatures)
    }

    /// Every Mac UI stack sits on AppKit, so AppKit is reported only when nothing more specific
    /// was found — including when nothing was found at all.
    private static func resolve(_ stacks: TechStack) -> TechStack {
        let specific = stacks.subtracting(.appKit)
        return specific.isEmpty ? .appKit : specific
    }

    // MARK: - Helpers

    private static func match(_ text: String, against signatures: [TextSignature]) -> TechStack {
        var stacks: TechStack = []
        for signature in signatures where signature.markers.contains(where: text.contains) {
            stacks.insert(signature.stack)
        }
        return stacks
    }
}
