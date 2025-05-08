import Foundation
import LSAppCategory

class DetectService {
    private let fileManager = FileManager.default

    // Constants for framework names, to be replaced or used within specific detection logic
    private let electronFrameworkNames = ["Electron Framework.framework"]
    private let microsoftEdgeFrameworkNames = ["Microsoft Edge Framework.framework"]
    private let cefFrameworkNames = ["Chromium Embedded Framework.framework"]

    // MARK: - Public API

    /// Main detection function that orchestrates the 6-step analysis of an app bundle.
    func detectStack(for appURL: URL) async -> TechStack {
        var detectedStacks: TechStack = []

        // --- Step 1: Get App URL to analyze
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
            print("[DetectService] Critical: Could not find or determine executable for \(appToAnalyzeURL.path). Returning .other")
            return .other
        }

        // --- Step 2: Framework Directory Analysis ---
        let frameworkStacks = scanFrameworksDirectory(
            frameworksPath: frameworksPath.path
        )
        detectedStacks.formUnion(frameworkStacks)
        if !frameworkStacks.isEmpty { print("[DetectService] Step 2: Frameworks detected: \(frameworkStacks.displayNames.joined(separator: ", "))") }

        // --- Step 3: Selective Resource Analysis ---
        let resourceStacks = scanResourcesDirectory(
            resourcesPath: resourcesPath.path,
            currentStacks: detectedStacks
        )
        detectedStacks.formUnion(resourceStacks)
        if !resourceStacks.isEmpty { print("[DetectService] Step 3: Resources detected: \(resourceStacks.displayNames.joined(separator: ", "))") }

        // --- Step 4: Binary Analysis (otool) ---
        let otoolStacks = checkExecutableLibrariesWithOtool(executableURL: executableURL)
        detectedStacks.formUnion(otoolStacks)
        if !otoolStacks.isEmpty { print("[DetectService] Step 4: otool analysis detected: \(otoolStacks.displayNames.joined(separator: ", "))") }

        if detectedStacks.isEmpty {
            let stringAnalysisStacks = checkStringsInExecutable(executableURL: executableURL)
            detectedStacks.formUnion(stringAnalysisStacks)
            if !stringAnalysisStacks.isEmpty { print("[DetectService] Step 5: Strings analysis detected: \(stringAnalysisStacks.displayNames.joined(separator: ", "))") }
        }

        // --- Step 6: Info.plist and Final Inference ---
        let finalResolvedStacks = resolveConflictsAndFallback(
            currentStacks: detectedStacks,
            appURL: appToAnalyzeURL,
            resourcesPath: resourcesPath.path,
            infoPlist: infoPlist
        )

        print("[DetectService] Final detected stacks for \(appToAnalyzeURL.lastPathComponent): \(finalResolvedStacks.displayNames.joined(separator: ", "))")
        return finalResolvedStacks
    }

    // MARK: - Detection Step Helper Functions

    /// Step 1: Get App Url to analyze, iOS App runs on macOS is WrappedBundle
    /// Returns the URL to analyze and whether it's a wrapped bundle.
    private func getAppUrlToAnalyze(appURL: URL) -> (URL, Bool) {
        let wrappedBundleUrl = appURL.appendingPathComponent("WrappedBundle")
        let path = wrappedBundleUrl.path

        guard fileManager.fileExists(atPath: path) else {
            return (appURL, false)
        }

        let fullResolved = URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
        print("[DetectService] Step 1: Fully resolved path: \(fullResolved)")

        return (fullResolved, true)
    }

    /// Step 2: Scans the Frameworks directory for known framework signatures (Electron, CEF, Flutter, .NET, Python, Qt).
    private func scanFrameworksDirectory(frameworksPath: String) -> TechStack {
        var detectedStacks: TechStack = []

        guard fileManager.fileExists(atPath: frameworksPath) else {
            print("[DetectService] Step 2: Frameworks directory does not exist at \(frameworksPath).")
            return detectedStacks
        }

        // Define indicators based on DetectionRules.md
        let electronIndicators = ["Electron Framework.framework"]
        let microsoftEdgeIndicators = ["Microsoft Edge Framework.framework"]
        let cefIndicators = ["Chromium Embedded Framework.framework"]
        let flutterSpecificFrameworks = ["FlutterMacOS.framework"]

        do {
            let frameworkItems = try fileManager.contentsOfDirectory(atPath: frameworksPath)

            for item in frameworkItems {
                // Electron
                if electronIndicators.contains(item) {
                    detectedStacks.insert(.electron)
                }

                // Microsoft Edge
                if microsoftEdgeIndicators.contains(item) {
                    detectedStacks.insert(.microsoftEdge)
                }

                // Chromium Embedded Framework (CEF)
                if cefIndicators.contains(item) {
                    detectedStacks.insert(.cef)
                }

                // Flutter
                if flutterSpecificFrameworks.contains(item) || item.contains("Flutter") {
                    detectedStacks.insert(.flutter)
                }

                // .NET/Xamarin/MAUI (Assemblies)
                // Look for common .NET assembly patterns or specific framework names
                if item.contains("Xamarin") || item.contains("Microsoft.Maui") || item.contains("MonoBundle") {
                    detectedStacks.insert(.xamarin)
                }

                // Python
                if item == "Python.framework" || (item.lowercased().contains("python") && item.hasSuffix(".framework")) {
                    detectedStacks.insert(.python)
                }

                // Qt frameworks often start with "Qt" e.g., QtCore.framework, or contain Qt in their name like QtWebEngineCore.framework
                if item.starts(with: "Qt") && item.hasSuffix(".framework") {
                    detectedStacks.insert(.qt)
                }
            }
        } catch {
            print("[DetectService] Step 2: Error reading Frameworks directory at \(frameworksPath): \(error.localizedDescription)")
        }

        return detectedStacks
    }

    /// Step 3: Performs selective resource analysis (AppKit Nibs, Flutter assets, React Native bundles).
    /// Only checks for stacks not already found by higher priority steps.
    private func scanResourcesDirectory(resourcesPath: String, currentStacks: TechStack) -> TechStack {
        var detectedStacks: TechStack = []

        guard fileManager.fileExists(atPath: resourcesPath) else {
            print("[DetectService] Step 3: Resources directory does not exist at \(resourcesPath).")
            return detectedStacks
        }

        // React Native: *.jsbundle files
        if !currentStacks.contains(.reactNative) {
            // Check for common React Native bundle names or any .jsbundle file
            if fileManager.fileExists(atPath: resourcesPath.appending("/main.jsbundle")) ||
                fileManager.fileExists(atPath: resourcesPath.appending("/index.bundle")) || // Some RN projects use index.bundle
                directoryContains(path: resourcesPath, extensions: ["jsbundle"])
            {
                print("[DetectService] Step 3: Detected React Native bundle (.jsbundle).")
                detectedStacks.insert(.reactNative)
            }
        }

        return detectedStacks
    }

    /// Step 4: Binary Analysis (otool) - Renamed from checkExecutableLibraries
    private func checkExecutableLibrariesWithOtool(executableURL: URL) -> TechStack {
        var detectedStacks: TechStack = []
        let pipe = Pipe()
        let errorPipe = Pipe()
        let process = Process()
        process.launchPath = "/usr/bin/otool"
        process.arguments = ["-L", executableURL.path]
        process.standardOutput = pipe
        process.standardError = errorPipe

        // print("[DetectService-otool] Running otool -L on \(executableURL.path)")
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            if let output = String(data: data, encoding: .utf8) {
                // Native Apple frameworks detection
                if output.contains("SwiftUI") { detectedStacks.insert(.swiftUI) }
                if output.contains("/System/iOSSupport/System/Library/Frameworks/UIKit.framework") { detectedStacks.insert(.catalyst) }
                if output
                    .contains(
                        "/System/Library/Frameworks/Cocoa.framework"
                    ) || output
                    .contains("/usr/lib/swift/libswiftAppKit.dylib")
                {
                    detectedStacks.insert(.appKit)
                }
                // Cross-platform frameworks detection
                if output.contains("Electron") || output.contains("Chromium") || output.contains("libnode") { detectedStacks.insert(.electron) }
                if cefFrameworkNames.contains(where: output.contains) || output.contains("libcef") { detectedStacks.insert(.cef) }
                if output.contains("Python") || output.contains("libpython") { detectedStacks.insert(.python) }
                if output.contains("QtCore") || output.contains("QtGui") { detectedStacks.insert(.qt) }
                if output.contains("wxWidgets") || output.contains("libwx_") { detectedStacks.insert(.wxWidgets) }
                if output.contains("libjvm") || output.contains("JavaVM") || output.contains("JavaNativeFoundation") { detectedStacks.insert(.java) }
                if output.contains("libmono") || output.contains("libcoreclr") || output.contains("Microsoft.Maui") { detectedStacks.insert(.xamarin) }
                if output.contains("Flutter") { detectedStacks.insert(.flutter) } // Flutter engine linked
                if output.contains("React Native") || output.contains("libjsi") || output.contains("libhermes") { detectedStacks.insert(.reactNative) }
                if output.contains("libgtk") || output.contains("libgdk") { detectedStacks.insert(.gtk) } // GTK libraries
            }
        } catch {
            print("[DetectService-otool] Error running otool: \(error)")
        }
        return detectedStacks
    }

    /// Helper to run 'otool -L' for a given executable URL.
    private func runOtool(for executableURL: URL) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/otool")
        process.arguments = ["-L", executableURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            if let output = String(data: data, encoding: .utf8) {
                return output.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            } else {
                print("[DetectService] runOtool: Failed to decode otool output for \(executableURL.path)")
                return []
            }
        } catch {
            print("[DetectService] runOtool: Failed to run otool for \(executableURL.path): \(error.localizedDescription)")
            return []
        }
    }

    /// Helper to run 'strings <executable>' and capture its output.
    private func runStrings(executableURL: URL, timeout: TimeInterval = 10.0) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/strings")
        process.arguments = [executableURL.path]

        // 1) Create and install the pipe
        let pipe = Pipe()
        process.standardOutput = pipe

        // 2) Read in the background
        var outputData = Data()
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fh in
            let chunk = fh.availableData
            if chunk.isEmpty {
                fh.readabilityHandler = nil // EOF
            } else {
                outputData.append(chunk)
            }
        }

        // 3) Use a DispatchGroup + terminationHandler instead of waitUntilExit()
        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in group.leave() }

        do {
            try process.run()
        } catch {
            print("Failed to launch strings:", error)
            return nil
        }

        // 4) Wait with timeout
        let result = group.wait(timeout: .now() + timeout)
        if result == .timedOut {
            print("Timeout – killing strings")
            process.terminate()
            return nil
        }

        return String(data: outputData, encoding: .utf8)
    }

    /// Step 5: Performs strings analysis on the executable for certain patterns (Tauri, wxWidgets, gpui, iced).
    private func checkStringsInExecutable(executableURL: URL) -> TechStack {
        print("[DetectService] Step 5: Analyzing executable with strings command: \(executableURL.path)")

        guard let stringsOutput = runStrings(executableURL: executableURL, timeout: 10) else {
            print("[DetectService] Step 5: Failed to get strings output or timed out for \(executableURL.path) after 30 seconds")
            return []
        }

        // Java
        if stringsOutput.contains("java/lang") {
            return [.java]
        }

        // Tauri: Presence of "tauri"
        if stringsOutput.contains("tauri") { // Case-sensitive as per typical binary content
            return [.tauri]
        }

        // wxWidgets: Presence of "wx_main" (secondary check)
        if stringsOutput.contains("wx_main") { // Case-sensitive for symbol-like strings
            return [.wxWidgets]
        }

        // GPUI: Presence of "gpui" (as per DetectionRules.md)
        if stringsOutput.contains("/gpui/") {
            return [.gpui]
        }

        // Iced: Presence of "iced_wgpu" (as per DetectionRules.md)
        if stringsOutput.contains("iced_wgpu") {
            return [.iced]
        }

        return []
    }

    /// Step 6: Resolves conflicts between detected stacks and applies final inferences.
    private func resolveConflictsAndFallback(currentStacks: TechStack, appURL: URL, resourcesPath: String, infoPlist: [String: Any]?) -> TechStack {
        var resolvedStacks = currentStacks

        // 1. Check nibs and storyboards for AppKit
        if directoryContains(path: resourcesPath, extensions: ["nib", "storyboardc"]) {
            print("[DetectService] Step 3: Detected AppKit resources (.nib/.storyboardc).")
            resolvedStacks.insert(.appKit)
        }

        // 2. Remove AppKit nif it has 2 major stacks
        if resolvedStacks.toArray.count > 2 {
            resolvedStacks.remove(.appKit)
        }

        if resolvedStacks.isEmpty {
            resolvedStacks.insert(.appKit)
        }

        print("[DetectService] Step 6: Finished conflict resolution. Final stacks: \(resolvedStacks.displayNames.joined(separator: ", "))")
        return resolvedStacks
    }

    /// Helper function to check if a directory contains files with given extensions (non-recursive for Resources).
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
            print("[DetectService] directoryContains: Error reading directory \(path): \(error.localizedDescription)")
        }
        return false
    }

    func extractCategory(from appURL: URL) -> AppCategory {
        let infoPlistPath = appURL.appendingPathComponent("Contents/Info.plist")
        let metadataPlistPath = appURL.appendingPathComponent("Wrapper/iTunesMetadata.plist")
        if let infoPlist = readInfoPlist(from: infoPlistPath),
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

    /// Reads the Info.plist file from the app bundle.
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

    /// Finds the main executable file within the app's MacOS directory.
    /// Prioritizes the name from CFBundleExecutable, falls back to scanning for any executable.
    private func findExecutable(in directoryPath: String, named executableName: String) -> URL? {
        let directoryURL = URL(fileURLWithPath: directoryPath)
        do {
            let directoryContents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            // First, try to find the executable with the exact name from Info.plist
            if let executableURL = directoryContents.first(where: { $0.lastPathComponent == executableName }) {
                return executableURL
            }
            // If not found, look for any executable file in the directory
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
