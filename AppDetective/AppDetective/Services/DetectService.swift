import Foundation

class DetectService {
    private let fileManager = FileManager.default

    // Known Electron framework directory names (add more as discovered)
    private let electronFrameworkNames: Set<String> = [
        "Electron Framework.framework",
        "Microsoft Edge Framework.framework"
        // "Other Electron Variant.framework"
    ]

    // Known CEF framework and library names
    private let cefFrameworkNames: Set<String> = [
        "Chromium Embedded Framework.framework",
        "chromehtml.dylib" // Found in Steam app
    ]

    // Helper function to run otool -L on the executable
    private func checkExecutableLibraries(executableURL: URL) -> TechStack {
        var detectedStacks: TechStack = []
        let pipe = Pipe()
        let process = Process()
        process.launchPath = "/usr/bin/otool"
        process.arguments = ["-L", executableURL.path]
        process.standardOutput = pipe

        print("[DetectService-otool] Running otool -L on \(executableURL.path)")

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Native Apple frameworks detection
                if output.contains("SwiftUI") {
                    print("[DetectService-otool] Detected SwiftUI library.")
                    detectedStacks.insert(.swiftUI)
                }
                if output.contains("/System/Library/Frameworks/AppKit.framework/") {
                    print("[DetectService-otool] Detected AppKit framework.")
                    detectedStacks.insert(.appKit)
                }
                if output.contains("/System/Library/Frameworks/UIKit.framework/") {
                    print("[DetectService-otool] Detected UIKit on macOS - likely Catalyst.")
                    detectedStacks.insert(.catalyst)
                }

                // Cross-platform frameworks detection

                // Electron/Chromium detection
                if output.contains("Electron") || output.contains("Chromium") ||
                    output.contains("libnode") || output.contains("libffmpeg")
                {
                    print("[DetectService-otool] Detected Electron/Chromium libraries.")
                    detectedStacks.insert(.electron)
                }

                // Chromium Embedded Framework detection
                if output.contains("Chromium Embedded Framework") ||
                   output.contains("libcef") ||
                   output.contains("chromehtml.dylib") {
                    print("[DetectService-otool] Detected Chromium Embedded Framework.")
                    detectedStacks.insert(.cef)
                }

                // Python detection
                if output.contains("Python") || output.contains("libpython") {
                    print("[DetectService-otool] Detected Python library linkage.")
                    detectedStacks.insert(.python)
                }

                // Qt detection
                if output.contains("QtCore") || output.contains("QtGui") || output.contains("Qt5") || output.contains("Qt6") {
                    print("[DetectService-otool] Detected Qt library linkage.")
                    detectedStacks.insert(.qt)
                }

                // wxWidgets detection
                if output.contains("wxWidgets") || output.contains("libwx_") {
                    print("[DetectService-otool] Detected wxWidgets library linkage.")
                    detectedStacks.insert(.wxWidgets)
                }

                // Java detection
                if output.contains("libjvm") || output.contains("JavaVM") || output.contains("JavaNativeFoundation") {
                    print("[DetectService-otool] Detected Java/JVM library linkage.")
                    detectedStacks.insert(.java)
                }

                // Xamarin/.NET detection
                if output.contains("libmono") || output.contains("libcoreclr") || output.contains("libMicrosoft.Maui") {
                    print("[DetectService-otool] Detected Xamarin/.NET library linkage.")
                    detectedStacks.insert(.xamarin)
                }

                // Flutter detection
                if output.contains("Flutter") || output.contains("libflutter") {
                    print("[DetectService-otool] Detected Flutter library linkage.")
                    detectedStacks.insert(.flutter)
                }

                // React Native detection
                if (output.contains("React") || output.contains("ReactNative")) &&
                    !output.contains("Flutter")
                { // To avoid misidentifying Flutter
                    print("[DetectService-otool] Detected React Native library linkage.")
                    detectedStacks.insert(.reactNative)
                }

                // Tauri/Rust detection
                if output.contains("librust") || output.contains("libtauri") || output.contains("libpake") {
                    print("[DetectService-otool] Detected Rust/Tauri library linkage.")
                    detectedStacks.insert(.tauri)
                }

                // Check for general Swift libraries (might indicate AppKit/UIKit without SwiftUI)
                if output.contains("/usr/lib/swift/libswift") || output.contains("@rpath/libswift") {
                    print("[DetectService-otool] Detected Swift libraries.")
                    // We can't definitively say AppKit or UIKit just from this,
                    // but it confirms Swift usage. Resource checks might differentiate later.
                }
            }
        } catch {
            print("[DetectService-otool] Error running otool: \(error)")
        }
        return detectedStacks
    }

    // Main detection function - now returns an OptionSet
    func detectStack(for appURL: URL) async -> TechStack {
        var detectedStacks: TechStack = []
        var appToAnalyzeURL = appURL // Start with the outer URL
        var hasCEFFramework = false // Track if we found CEF framework

        // --- Priority 0: Check for Wrapped iOS App Structure ---

        // First pattern: Check for root-level "WrappedBundle" symlink pointing to an app in Wrapper directory
        let rootWrappedBundleSymlinkPath = appURL.appendingPathComponent("WrappedBundle").path
        let wrapperPath = appURL.appendingPathComponent("Wrapper").path

        if fileManager.fileExists(atPath: rootWrappedBundleSymlinkPath) && fileManager.fileExists(atPath: wrapperPath) {
            print("[DetectService] Detected root-level WrappedBundle symlink, likely iOS app on Mac.")
            do {
                // Resolve the symlink at root level
                let symlinkDest = try fileManager.destinationOfSymbolicLink(atPath: rootWrappedBundleSymlinkPath)
                print("[DetectService] WrappedBundle symlink points to: \(symlinkDest)")

                // Handle both absolute and relative symlinks
                var innerAppPath: String
                if symlinkDest.hasPrefix("/") {
                    // Absolute path
                    innerAppPath = symlinkDest
                } else {
                    // Relative path - might be relative to app root or directly point to Wrapper/[app].app
                    if symlinkDest.hasPrefix("Wrapper/") {
                        innerAppPath = URL(fileURLWithPath: appURL.path).appendingPathComponent(symlinkDest).path
                    } else {
                        // Try to find it in Wrapper directory
                        innerAppPath = URL(fileURLWithPath: wrapperPath).appendingPathComponent(symlinkDest).path
                    }
                }

                if innerAppPath.hasSuffix(".app") && fileManager.fileExists(atPath: innerAppPath) {
                    appToAnalyzeURL = URL(fileURLWithPath: innerAppPath)
                    print("[DetectService] Analyzing inner app bundle via root symlink: \(appToAnalyzeURL.path)")
                    detectedStacks.insert(.catalyst) // Strong indicator
                } else {
                    print("[DetectService] WrappedBundle symlink does not point to a valid .app: \(innerAppPath)")

                    // Fallback: Try finding the first .app in Wrapper if symlink didn't resolve to a valid app
                    if let wrapperContents = try? fileManager.contentsOfDirectory(atPath: wrapperPath),
                       let innerAppName = wrapperContents.first(where: { $0.hasSuffix(".app") })
                    {
                        appToAnalyzeURL = URL(fileURLWithPath: wrapperPath).appendingPathComponent(innerAppName)
                        print("[DetectService] Analyzing inner app bundle (fallback): \(appToAnalyzeURL.path)")
                        detectedStacks.insert(.catalyst)
                    }
                }
            } catch {
                print("[DetectService] Error reading WrappedBundle symlink: \(error). Trying alternate detection methods.")

                // Fallback: Look for an app directly in the Wrapper directory
                if fileManager.fileExists(atPath: wrapperPath) {
                    do {
                        let wrapperContents = try fileManager.contentsOfDirectory(atPath: wrapperPath)
                        if let innerAppName = wrapperContents.first(where: { $0.hasSuffix(".app") }) {
                            appToAnalyzeURL = URL(fileURLWithPath: wrapperPath).appendingPathComponent(innerAppName)
                            print("[DetectService] Analyzing inner app bundle from Wrapper: \(appToAnalyzeURL.path)")
                            detectedStacks.insert(.catalyst)
                        }
                    } catch {
                        print("[DetectService] Error reading Wrapper directory: \(error)")
                    }
                }
            }
        }
        // Second pattern: Check for the older Wrapper/WrappedBundle structure
        else if fileManager.fileExists(atPath: wrapperPath) {
            let wrappedBundleSymlinkPath = wrapperPath + "/WrappedBundle"

            if fileManager.fileExists(atPath: wrappedBundleSymlinkPath) {
                print("[DetectService] Detected Wrapper/WrappedBundle structure, likely iOS app on Mac.")
                do {
                    // Resolve the symlink within Wrapper directory
                    let symlinkDest = try fileManager.destinationOfSymbolicLink(atPath: wrappedBundleSymlinkPath)
                    // Destination is relative to the symlink's directory (Wrapper)
                    let innerAppPath = URL(fileURLWithPath: wrapperPath).appendingPathComponent(symlinkDest).path

                    if innerAppPath.hasSuffix(".app") && fileManager.fileExists(atPath: innerAppPath) {
                        appToAnalyzeURL = URL(fileURLWithPath: innerAppPath)
                        print("[DetectService] Analyzing inner app bundle: \(appToAnalyzeURL.path)")
                        detectedStacks.insert(.catalyst) // Strong indicator
                    } else {
                        print("[DetectService] WrappedBundle symlink in Wrapper does not point to a valid .app: \(symlinkDest)")
                        // Fallback: Try finding the first .app in Wrapper if symlink failed
                        if let wrapperContents = try? fileManager.contentsOfDirectory(atPath: wrapperPath),
                           let innerAppName = wrapperContents.first(where: { $0.hasSuffix(".app") })
                        {
                            appToAnalyzeURL = URL(fileURLWithPath: wrapperPath).appendingPathComponent(innerAppName)
                            print("[DetectService] Analyzing inner app bundle (fallback): \(appToAnalyzeURL.path)")
                            detectedStacks.insert(.catalyst)
                        }
                    }
                } catch {
                    print("[DetectService] Error reading WrappedBundle symlink: \(error). Trying direct app detection.")
                    // Fallback: Look for any .app file directly in Wrapper
                    do {
                        let wrapperContents = try fileManager.contentsOfDirectory(atPath: wrapperPath)
                        if let innerAppName = wrapperContents.first(where: { $0.hasSuffix(".app") }) {
                            appToAnalyzeURL = URL(fileURLWithPath: wrapperPath).appendingPathComponent(innerAppName)
                            print("[DetectService] Found app directly in Wrapper: \(appToAnalyzeURL.path)")
                            detectedStacks.insert(.catalyst)
                        }
                    } catch {
                        print("[DetectService] Error scanning Wrapper directory: \(error)")
                    }
                }
            }
            // If no WrappedBundle symlink in Wrapper, still check for direct .app files
            else {
                do {
                    let wrapperContents = try fileManager.contentsOfDirectory(atPath: wrapperPath)
                    if let innerAppName = wrapperContents.first(where: { $0.hasSuffix(".app") }) {
                        appToAnalyzeURL = URL(fileURLWithPath: wrapperPath).appendingPathComponent(innerAppName)
                        print("[DetectService] Found app directly in Wrapper without symlink: \(appToAnalyzeURL.path)")
                        detectedStacks.insert(.catalyst)
                    }
                } catch {
                    print("[DetectService] Error scanning Wrapper directory: \(error)")
                }
            }
        }

        // Before proceeding, verify the app bundle still exists and is valid
        if !fileManager.fileExists(atPath: appToAnalyzeURL.path) {
            print("[DetectService] Warning: Selected app bundle path doesn't exist: \(appToAnalyzeURL.path)")
            print("[DetectService] Falling back to original app URL: \(appURL.path)")
            appToAnalyzeURL = appURL
        }

        // --- Define paths based on the app we are actually analyzing ---
        let frameworksPath = appToAnalyzeURL.appendingPathComponent("Contents/Frameworks").path
        let resourcesPath = appToAnalyzeURL.appendingPathComponent("Contents/Resources").path
        let macosPath = appToAnalyzeURL.appendingPathComponent("Contents/MacOS").path

        // --- FIRST PRIORITY: Check for CEF/Electron frameworks ---
        // We check for CEF first to prioritize this over AppKit detection
        if fileManager.fileExists(atPath: frameworksPath) {
            do {
                let frameworkItems = try fileManager.contentsOfDirectory(atPath: frameworksPath)

                // Check specifically for CEF first
                for item in frameworkItems {
                    if cefFrameworkNames.contains(item) {
                        print("[DetectService] Detected CEF framework: \(item)")
                        detectedStacks.insert(.cef)
                        hasCEFFramework = true
                        break // Found CEF, no need to continue checking
                    }
                }

                // If no CEF found, check for Electron
                if !hasCEFFramework {
                    for item in frameworkItems {
                        if electronFrameworkNames.contains(item) {
                            print("[DetectService] Detected Electron framework: \(item)")
                            detectedStacks.insert(.electron)
                            break
                        }
                    }
                }

                // Check for other frameworks
                for item in frameworkItems {
                    if item.contains("Flutter") {
                        print("[DetectService] Detected Flutter framework.")
                        detectedStacks.insert(.flutter)
                    }
                    if item.contains("Xamarin") || item.contains("Microsoft.Maui") {
                        print("[DetectService] Detected Xamarin/MAUI framework/library.")
                        detectedStacks.insert(.xamarin)
                    }
                    if item.lowercased().contains("qt") {
                        print("[DetectService] Detected Qt framework.")
                        detectedStacks.insert(.qt)
                    }
                }
            } catch {
                print("[DetectService] Error reading Frameworks directory: \(error)")
            }
        }

        // --- SECOND PRIORITY: Check Executable with otool (using appToAnalyzeURL) ---
        if let executableName = getExecutableName(from: appToAnalyzeURL),
           let executableURL = findExecutable(in: macosPath, named: executableName)
        {
            let otoolStacks = checkExecutableLibraries(executableURL: executableURL)

            // If we already found CEF framework, and otool detected AppKit,
            // don't add AppKit to detected stacks since this is likely a false positive
            // for CEF applications (many CEF apps use some AppKit components)
            if hasCEFFramework && otoolStacks.contains(.appKit) {
                var filteredStacks = otoolStacks
                filteredStacks.remove(.appKit)
                print("[DetectService] Removing AppKit detection since CEF framework was found")
                detectedStacks.formUnion(filteredStacks)
            } else {
                detectedStacks.formUnion(otoolStacks)
            }
        } else {
            print("[DetectService] Could not find or determine executable for otool check in \(appToAnalyzeURL.path).")
        }

        // --- Priority 3: Check Specific Known Structures (using appToAnalyzeURL) ---

        // Check for Tauri (pake)
        if fileManager.fileExists(atPath: macosPath + "/pake") {
            print("[DetectService] Detected Tauri (pake executable).")
            detectedStacks.insert(.tauri)
            // Tauri apps often use Swift libs too, otool might have caught .swiftUI
            // but we prioritize the Tauri flag here if pake exists.
        }

        // --- Priority 4: Check Resources Directory (using appToAnalyzeURL) ---
        if fileManager.fileExists(atPath: resourcesPath) {
            // Check for AppKit Nibs/Storyboards
            if directoryContains(path: resourcesPath, extensions: ["nib", "storyboardc"]) {
                // Only add AppKit if we haven't found CEF
                if !hasCEFFramework {
                    print("[DetectService] Detected AppKit resources (.nib/.storyboardc).")
                    detectedStacks.insert(.appKit)
                } else {
                    print("[DetectService] Found AppKit resources but CEF takes priority.")
                }
            }

            // Check for Electron 'app.asar' or 'app' directory
            if fileManager.fileExists(atPath: resourcesPath + "/app.asar") || fileManager.fileExists(atPath: resourcesPath + "/app") {
                if !detectedStacks.contains(.electron) { // Check if not already found via framework
                    print("[DetectService] Detected Electron resources (app.asar or app dir).")
                    detectedStacks.insert(.electron)
                }
            }
            // Check for Java resources (.jar files)
            if directoryContains(path: resourcesPath, extensions: ["jar"]) {
                print("[DetectService] Detected Java resources (.jar).")
                detectedStacks.insert(.java)
            }
            // Check for Flutter assets
            if fileManager.fileExists(atPath: resourcesPath + "/flutter_assets") {
                if !detectedStacks.contains(.flutter) {
                    print("[DetectService] Detected Flutter resources (flutter_assets).")
                    detectedStacks.insert(.flutter)
                }
            }
            // Check for React Native bundle
            if fileManager.fileExists(atPath: resourcesPath + "/main.jsbundle") || fileManager.fileExists(atPath: resourcesPath + "/index.bundle") {
                print("[DetectService] Detected React Native bundle.")
                detectedStacks.insert(.reactNative)
            }
        }

        // --- Priority 5: Infer AppKit/UIKit based on Info.plist and otool (using appToAnalyzeURL) ---
        if let infoPlist = readInfoPlist(from: appToAnalyzeURL) {
            // Check for Catalyst marker explicitly (might be redundant if Wrapper detected, but good to check)
            if infoPlist["LSRequiresNativeExecution"] as? Bool == true {
                print("[DetectService] Detected Catalyst via Info.plist.")
                detectedStacks.insert(.catalyst)
            }

            // Refined AppKit Inference: Only if we haven't detected CEF already
            if !hasCEFFramework {
                let swiftLinked = checkExecutableLibraries(executableURL: findExecutable(in: macosPath, named: getExecutableName(from: appToAnalyzeURL) ?? "")!).rawValue > 0 // Re-check otool for Swift linkage (crude)
                if !detectedStacks.contains(.swiftUI) &&
                   !detectedStacks.contains(.appKit) && // Check if not already found
                   !detectedStacks.contains(.catalyst) && // Ensure not Catalyst
                   swiftLinked
                {
                    print("[DetectService] Inferring AppKit based on Swift linkage (no SwiftUI/Nibs/Catalyst).")
                    detectedStacks.insert(.appKit)
                }
            }
        }

        // --- Final Cleanup & Fallback ---

        // Rule: CEF takes priority over AppKit
        if detectedStacks.contains(.cef) && detectedStacks.contains(.appKit) {
            detectedStacks.remove(.appKit)
            print("[DetectService] Prioritizing CEF over AppKit in final detection")
        }

        // Rule: Catalyst takes priority over AppKit
        if detectedStacks.contains(.catalyst) {
            detectedStacks.remove(.appKit)
            print("[DetectService] Prioritizing UIKit/Catalyst over AppKit")
        }

        // Rule: Electron takes priority over AppKit
        if detectedStacks.contains(.electron) && detectedStacks.contains(.appKit) {
            detectedStacks.remove(.appKit)
            print("[DetectService] Prioritizing Electron over AppKit in final detection")
        }

        if detectedStacks.isEmpty {
            print("[DetectService] No specific stack detected for \(appURL.lastPathComponent), using AppKit as fallback.")
            detectedStacks.insert(.appKit) // Use AppKit instead of .other as fallback
        }

        print("[DetectService] Final detected stacks for \(appURL.lastPathComponent): \(detectedStacks.displayNames.joined(separator: ", "))")
        return detectedStacks
    }

    /// Extracts the application category from the Info.plist file
    /// - Parameter appURL: The URL of the app bundle
    /// - Returns: A Category enum representing the app's category
    func extractCategory(from appURL: URL) -> Category {
        if let infoPlist = readInfoPlist(from: appURL),
           let categoryType = infoPlist["LSApplicationCategoryType"] as? String {
            print("[DetectService] Found category: \(categoryType)")
            return Category(fromSystemCategory: categoryType)
        }
        return .uncategorized
    }

    // Helper to read Info.plist
    private func readInfoPlist(from appURL: URL) -> [String: Any]? {
        let plistPath = appURL.appendingPathComponent("Contents/Info.plist").path
        guard fileManager.fileExists(atPath: plistPath),
              let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath))
        else {
            return nil
        }
        return try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any]
    }

    // Helper to get executable name from Info.plist
    private func getExecutableName(from appURL: URL) -> String? {
        return readInfoPlist(from: appURL)?["CFBundleExecutable"] as? String
    }

    // Helper to find the actual executable file
    private func findExecutable(in macosDir: String, named execName: String) -> URL? {
        let execURL = URL(fileURLWithPath: macosDir).appendingPathComponent(execName)
        if fileManager.isExecutableFile(atPath: execURL.path) {
            return execURL
        }
        // Fallback: Sometimes the executable might be different (e.g., helper)
        // Look for the first executable file in Contents/MacOS if primary not found
        if let contents = try? fileManager.contentsOfDirectory(at: URL(fileURLWithPath: macosDir), includingPropertiesForKeys: [.isExecutableKey], options: .skipsHiddenFiles) {
            for fileURL in contents {
                if (try? fileURL.resourceValues(forKeys: [.isExecutableKey]).isExecutable) == true {
                    print("[DetectService] Found fallback executable: \(fileURL.lastPathComponent)")
                    return fileURL
                }
            }
        }
        return nil // Not found
    }

    // Helper function to check if a directory contains files with specific extensions
    private func directoryContains(path: String, extensions: [String]) -> Bool {
        guard let enumerator = fileManager.enumerator(atPath: path) else { return false }
        for case let file as String in enumerator {
            if extensions.contains((file as NSString).pathExtension.lowercased()) {
                return true
            }
        }
        return false
    }
}
