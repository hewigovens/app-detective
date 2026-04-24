import Foundation
import LSAppCategory

public final class DetectService {
    private let fileManager = FileManager.default

    private let electronFrameworkNames = ["Electron Framework.framework"]
    private let microsoftEdgeFrameworkNames = ["Microsoft Edge Framework.framework"]
    private let cefFrameworkNames = ["Chromium Embedded Framework.framework"]

    public init() {}

    // MARK: - Public API

    /// Orchestrates the 6-step analysis of an app bundle to detect its tech stack.
    public func detectStack(for appURL: URL) async -> TechStack {
        var detectedStacks: TechStack = []

        let (appToAnalyzeURL, iOSAppOnMac) = getAppUrlToAnalyze(appURL: appURL)

        let contentsUrl = if iOSAppOnMac {
            appToAnalyzeURL
        } else {
            appToAnalyzeURL.appendingPathComponent("Contents")
        }
        let executableDir = if iOSAppOnMac {
            contentsUrl
        } else {
            contentsUrl.appendingPathComponent("MacOS")
        }
        let infoPlistUrl = contentsUrl.appendingPathComponent("Info.plist")
        let frameworksPath = contentsUrl.appendingPathComponent("/Frameworks")
        let resourcesPath = contentsUrl.appendingPathComponent("/Resources")

        guard
            let infoPlist = readInfoPlist(from: infoPlistUrl),
            let executableName = infoPlist["CFBundleExecutable"] as? String,
            let executableURL = findExecutable(
                in: executableDir.path,
                named: executableName
            )
        else {
            return .other
        }

        // Step 2: Framework directory analysis
        let frameworkStacks = scanFrameworksDirectory(frameworksPath: frameworksPath.path)
        detectedStacks.formUnion(frameworkStacks)

        // Step 3: Resource analysis
        let resourceStacks = scanResourcesDirectory(resourcesPath: resourcesPath.path, currentStacks: detectedStacks)
        detectedStacks.formUnion(resourceStacks)

        // Step 4: Binary analysis (otool)
        let otoolStacks = checkExecutableLibrariesWithOtool(executableURL: executableURL)
        detectedStacks.formUnion(otoolStacks)

        // Step 5: Strings fallback (only if nothing detected yet)
        if detectedStacks.isEmpty {
            let stringAnalysisStacks = checkStringsInExecutable(executableURL: executableURL)
            detectedStacks.formUnion(stringAnalysisStacks)
        }

        // Step 6: Conflict resolution and final inference
        let finalResolvedStacks = resolveConflictsAndFallback(
            currentStacks: detectedStacks,
            appURL: appToAnalyzeURL,
            resourcesPath: resourcesPath.path,
            infoPlist: infoPlist
        )

        return finalResolvedStacks
    }

    public func extractCategory(from appURL: URL) -> AppCategory {
        let (resolvedURL, _) = getAppUrlToAnalyze(appURL: appURL)
        let contentsInfoPlist = resolvedURL.appendingPathComponent("Contents/Info.plist")
        let rootInfoPlist = resolvedURL.appendingPathComponent("Info.plist")
        let metadataPlistPath = appURL.appendingPathComponent("Wrapper/iTunesMetadata.plist")

        if let infoPlist = readInfoPlist(from: contentsInfoPlist) ?? readInfoPlist(from: rootInfoPlist),
           let categoryType = infoPlist["LSApplicationCategoryType"] as? String?
        {
            return AppCategory(string: categoryType)
        } else if
            let metadataPlist = readInfoPlist(from: metadataPlistPath),
            let categories = metadataPlist["categories"] as? [String],
            let categoryType = categories.first
        {
            return AppCategory(string: categoryType)
        }

        return .other
    }

    // MARK: - Detection Steps

    /// Step 1: Resolves the actual app URL, handling iOS-on-Mac wrapped bundles.
    public func getAppUrlToAnalyze(appURL: URL) -> (URL, Bool) {
        let wrappedBundleUrl = appURL.appendingPathComponent("WrappedBundle")
        let path = wrappedBundleUrl.path

        guard fileManager.fileExists(atPath: path) else {
            return (appURL, false)
        }

        let fullResolved = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        return (fullResolved, true)
    }

    /// Step 2: Scans the Frameworks directory for known framework signatures.
    public func scanFrameworksDirectory(frameworksPath: String) -> TechStack {
        var detectedStacks: TechStack = []

        guard fileManager.fileExists(atPath: frameworksPath) else {
            return detectedStacks
        }

        let electronIndicators = ["Electron Framework.framework"]
        let microsoftEdgeIndicators = ["Microsoft Edge Framework.framework"]
        let cefIndicators = ["Chromium Embedded Framework.framework"]
        let flutterSpecificFrameworks = ["FlutterMacOS.framework"]

        do {
            let frameworkItems = try fileManager.contentsOfDirectory(atPath: frameworksPath)

            for item in frameworkItems {
                if electronIndicators.contains(item) { detectedStacks.insert(.electron) }
                if microsoftEdgeIndicators.contains(item) { detectedStacks.insert(.microsoftEdge) }
                if cefIndicators.contains(item) { detectedStacks.insert(.cef) }
                if flutterSpecificFrameworks.contains(item) || item.contains("Flutter") { detectedStacks.insert(.flutter) }
                if item.contains("Xamarin") || item.contains("Microsoft.Maui") || item.contains("MonoBundle") { detectedStacks.insert(.xamarin) }
                if item == "Python.framework" || (item.lowercased().contains("python") && item.hasSuffix(".framework")) { detectedStacks.insert(.python) }
                if item.starts(with: "Qt") && item.hasSuffix(".framework") { detectedStacks.insert(.qt) }
            }
        } catch {
            print("[DetectService] Error reading Frameworks directory: \(error.localizedDescription)")
        }

        return detectedStacks
    }

    /// Step 3: Selective resource analysis (React Native bundles, etc.).
    private func scanResourcesDirectory(resourcesPath: String, currentStacks: TechStack) -> TechStack {
        var detectedStacks: TechStack = []

        guard fileManager.fileExists(atPath: resourcesPath) else {
            return detectedStacks
        }

        if !currentStacks.contains(.reactNative) {
            if fileManager.fileExists(atPath: resourcesPath.appending("/main.jsbundle")) ||
                fileManager.fileExists(atPath: resourcesPath.appending("/index.bundle")) ||
                directoryContains(path: resourcesPath, extensions: ["jsbundle"])
            {
                detectedStacks.insert(.reactNative)
            }
        }

        return detectedStacks
    }

    /// Step 4: Binary analysis via otool -L.
    private func checkExecutableLibrariesWithOtool(executableURL: URL) -> TechStack {
        var detectedStacks: TechStack = []
        let pipe = Pipe()
        let errorPipe = Pipe()
        let process = Process()
        process.launchPath = "/usr/bin/otool"
        process.arguments = ["-L", executableURL.path]
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            if let output = String(data: data, encoding: .utf8) {
                // Native frameworks
                if output.contains("SwiftUI") { detectedStacks.insert(.swiftUI) }
                if output.contains("/System/iOSSupport/System/Library/Frameworks/UIKit.framework") { detectedStacks.insert(.catalyst) }
                if output.contains("/System/Library/Frameworks/Cocoa.framework") ||
                    output.contains("/usr/lib/swift/libswiftAppKit.dylib") {
                    detectedStacks.insert(.appKit)
                }

                // Cross-platform frameworks
                if output.contains("Electron") || output.contains("Chromium") || output.contains("libnode") { detectedStacks.insert(.electron) }
                if cefFrameworkNames.contains(where: output.contains) || output.contains("libcef") { detectedStacks.insert(.cef) }
                if output.contains("Python") || output.contains("libpython") { detectedStacks.insert(.python) }
                if output.contains("QtCore") || output.contains("QtGui") { detectedStacks.insert(.qt) }
                if output.contains("wxWidgets") || output.contains("libwx_") { detectedStacks.insert(.wxWidgets) }
                if output.contains("libjvm") || output.contains("JavaVM") || output.contains("JavaNativeFoundation") { detectedStacks.insert(.java) }
                if output.contains("libmono") || output.contains("libcoreclr") || output.contains("Microsoft.Maui") { detectedStacks.insert(.xamarin) }
                if output.contains("Flutter") { detectedStacks.insert(.flutter) }
                if output.contains("React Native") || output.contains("libjsi") || output.contains("libhermes") { detectedStacks.insert(.reactNative) }
                if output.contains("libgtk") || output.contains("libgdk") { detectedStacks.insert(.gtk) }
            }
        } catch {
            print("[DetectService] Error running otool: \(error)")
        }
        return detectedStacks
    }

    private func runStrings(executableURL: URL, timeout: TimeInterval = 10.0) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/strings")
        process.arguments = [executableURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe

        var outputData = Data()
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fh in
            let chunk = fh.availableData
            if chunk.isEmpty {
                fh.readabilityHandler = nil
            } else {
                outputData.append(chunk)
            }
        }

        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in group.leave() }

        do {
            try process.run()
        } catch {
            print("[DetectService] Failed to launch strings: \(error)")
            return nil
        }

        let result = group.wait(timeout: .now() + timeout)
        if result == .timedOut {
            process.terminate()
            return nil
        }

        return String(data: outputData, encoding: .utf8)
    }

    /// Step 5: Strings analysis for patterns not detectable by otool (Tauri, wxWidgets, GPUI, Iced).
    private func checkStringsInExecutable(executableURL: URL) -> TechStack {
        guard let stringsOutput = runStrings(executableURL: executableURL, timeout: 10) else {
            return []
        }

        var detectedStacks: TechStack = []

        if stringsOutput.contains("java/lang") { detectedStacks.insert(.java) }
        if stringsOutput.contains("gpui::") || stringsOutput.contains("/gpui/") { detectedStacks.insert(.gpui) }
        if stringsOutput.contains("tauri") { detectedStacks.insert(.tauri) }
        if stringsOutput.contains("wx_main") { detectedStacks.insert(.wxWidgets) }
        if stringsOutput.contains("iced_wgpu") { detectedStacks.insert(.iced) }

        return detectedStacks
    }

    /// Step 6: Resolves conflicts between detected stacks and applies fallback logic.
    private func resolveConflictsAndFallback(currentStacks: TechStack, appURL: URL, resourcesPath: String, infoPlist: [String: Any]?) -> TechStack {
        var resolvedStacks = currentStacks

        if directoryContains(path: resourcesPath, extensions: ["nib", "storyboardc"]) {
            resolvedStacks.insert(.appKit)
        }

        // Remove AppKit if more than 2 major stacks detected (likely a false positive)
        if resolvedStacks.toArray.count > 2 {
            resolvedStacks.remove(.appKit)
        }

        if resolvedStacks.isEmpty {
            resolvedStacks.insert(.appKit)
        }

        return resolvedStacks
    }

    // MARK: - Helpers

    private func directoryContains(path: String, extensions: [String]) -> Bool {
        guard fileManager.fileExists(atPath: path) else { return false }
        do {
            let items = try fileManager.contentsOfDirectory(atPath: path)
            for item in items {
                for ext in extensions {
                    if item.lowercased().hasSuffix(".\(ext.lowercased())") {
                        return true
                    }
                }
            }
        } catch {
            print("[DetectService] Error reading directory \(path): \(error.localizedDescription)")
        }
        return false
    }

    private func readInfoPlist(from infoPlist: URL) -> [String: Any]? {
        do {
            guard let plistData = try? Data(contentsOf: infoPlist) else {
                return nil
            }
            return try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any]
        } catch {
            print("[DetectService] Error parsing Info.plist at \(infoPlist.path): \(error.localizedDescription)")
            return nil
        }
    }

    private func findExecutable(in directoryPath: String, named executableName: String) -> URL? {
        let directoryURL = URL(fileURLWithPath: directoryPath)
        do {
            let directoryContents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            if let executableURL = directoryContents.first(where: { $0.lastPathComponent == executableName }) {
                return executableURL
            }
            for item in directoryContents {
                if item.pathExtension == "app" || item.pathExtension == "dylib" || item.pathExtension == "framework" {
                    return item
                }
            }
        } catch {
            print("[DetectService] Error finding executable in \(directoryPath): \(error.localizedDescription)")
        }
        return nil
    }
}
