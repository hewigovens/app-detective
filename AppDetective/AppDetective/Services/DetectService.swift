import Foundation

class DetectService {
    private let fileManager = FileManager.default

    // Known Electron framework directory names (add more as discovered)
    private let electronFrameworkNames: Set<String> = [
        "Electron Framework.framework",
        "Microsoft Edge Framework.framework"
        // "Other Electron Variant.framework"
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
                // print("[DetectService-otool] Output:\n\(output)") // Debug: Print full output
                if output.contains("SwiftUI") {
                    print("[DetectService-otool] Detected SwiftUI library.")
                    detectedStacks.insert(.swiftUI)
                }
                // Check for general Swift libraries (might indicate AppKit/UIKit without SwiftUI)
                if output.contains("/usr/lib/swift/libswift") || output.contains("@rpath/libswift") {
                    print("[DetectService-otool] Detected Swift libraries.")
                    // We can't definitively say AppKit or UIKit just from this,
                    // but it confirms Swift usage. Resource checks might differentiate later.
                }
                // Add checks for other specific dylibs if needed (e.g., Qt, Python)
                if output.contains("Python") {
                    print("[DetectService-otool] Detected Python library linkage.")
                    detectedStacks.insert(.python)
                }
                if output.contains("Qt") { // Or specific Qt library names
                    print("[DetectService-otool] Detected Qt library linkage.")
                    detectedStacks.insert(.qt)
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

        // --- Priority 0: Check for Wrapped iOS App Structure --- 
        let wrapperPath = appURL.appendingPathComponent("Wrapper").path
        let wrappedBundleSymlinkPath = wrapperPath + "/WrappedBundle"
        
        if fileManager.fileExists(atPath: wrapperPath), 
           fileManager.fileExists(atPath: wrappedBundleSymlinkPath) {
           
            print("[DetectService] Detected Wrapper structure, likely iOS app on Mac.")
            do {
                 // Resolve the symlink or find the .app inside Wrapper
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
                         let innerAppName = wrapperContents.first(where: { $0.hasSuffix(".app") }) {
                           appToAnalyzeURL = URL(fileURLWithPath: wrapperPath).appendingPathComponent(innerAppName)
                           print("[DetectService] Analyzing inner app bundle (fallback): \(appToAnalyzeURL.path)")
                           detectedStacks.insert(.catalyst)
                      } else {
                           print("[DetectService] Could not determine inner app bundle within Wrapper.")
                           // Continue analysis on the outer app, but the result might be less accurate
                      }
                 }
            } catch {
                 print("[DetectService] Error reading WrappedBundle symlink: \(error). Continuing with outer bundle.")
            }
        }

        // --- Define paths based on the app we are actually analyzing --- 
        let frameworksPath = appToAnalyzeURL.appendingPathComponent("Contents/Frameworks").path
        let resourcesPath = appToAnalyzeURL.appendingPathComponent("Contents/Resources").path
        let macosPath = appToAnalyzeURL.appendingPathComponent("Contents/MacOS").path

        // --- Priority 1: Check Executable with otool (using appToAnalyzeURL) ---
        if let executableName = getExecutableName(from: appToAnalyzeURL),
           let executableURL = findExecutable(in: macosPath, named: executableName)
        {
            let otoolStacks = checkExecutableLibraries(executableURL: executableURL)
            detectedStacks.formUnion(otoolStacks)
        } else {
            print("[DetectService] Could not find or determine executable for otool check in \(appToAnalyzeURL.path).")
        }

        // --- Priority 2: Check Specific Known Structures (using appToAnalyzeURL) --- 

        // Check for Tauri (pake)
        if fileManager.fileExists(atPath: macosPath + "/pake") {
            print("[DetectService] Detected Tauri (pake executable).")
            detectedStacks.insert(.tauri)
            // Tauri apps often use Swift libs too, otool might have caught .swiftUI
            // but we prioritize the Tauri flag here if pake exists.
        }

        // --- Priority 3: Check Frameworks Directory (using appToAnalyzeURL) --- 
        if fileManager.fileExists(atPath: frameworksPath) {
            do {
                let frameworkItems = try fileManager.contentsOfDirectory(atPath: frameworksPath)
                for item in frameworkItems {
                    if electronFrameworkNames.contains(item) {
                        print("[DetectService] Detected Electron framework: \(item)")
                        detectedStacks.insert(.electron)
                        break // Found one Electron variant, no need to check others
                    }
                    if item.contains("Flutter") { // e.g., FlutterEmbedder.framework
                        print("[DetectService] Detected Flutter framework.")
                        detectedStacks.insert(.flutter)
                    }
                    if item.contains("Xamarin") || item.contains("Microsoft.Maui") { // Xamarin.Mac.framework, Microsoft.Maui.dll?
                        print("[DetectService] Detected Xamarin/MAUI framework/library.")
                        detectedStacks.insert(.xamarin)
                    }
                    if item.lowercased().contains("qt") { // Qt*.framework
                        print("[DetectService] Detected Qt framework.")
                        detectedStacks.insert(.qt)
                    }
                    // Note: SwiftUI, AppKit, UIKit frameworks are usually system-level,
                    // not typically bundled here unless it's special.
                    // otool check is more reliable for these.
                }
            } catch {
                print("[DetectService] Error reading Frameworks directory: \(error)")
            }
        }

        // --- Priority 4: Check Resources Directory (using appToAnalyzeURL) --- 
        if fileManager.fileExists(atPath: resourcesPath) {
            // Check for AppKit Nibs/Storyboards
            if directoryContains(path: resourcesPath, extensions: ["nib", "storyboardc"]) {
                 print("[DetectService] Detected AppKit resources (.nib/.storyboardc).")
                 detectedStacks.insert(.appKit)
            }
            
            // Check for Electron 'app.asar' or 'app' directory
            if fileManager.fileExists(atPath: resourcesPath + "/app.asar") || fileManager.fileExists(atPath: resourcesPath + "/app") {
                if !detectedStacks.contains(.electron) { // Check if not already found via framework
                    print("[DetectService] Detected Electron resources (app.asar or app dir).")
                    detectedStacks.insert(.electron)
                }
            }
            // Check for Python resources (e.g., .pyc files, specific lib folders)
            if directoryContains(path: resourcesPath, extensions: ["py", "pyc"]) {
                if !detectedStacks.contains(.python) { // Check if not already found via otool
                    print("[DetectService] Detected Python resources.")
                    detectedStacks.insert(.python)
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
            // Check for generic web wrapper indicators (e.g., specific HTML/JS files if not Electron/RN)
            // This is less reliable and should have lower priority
            // if fileManager.fileExists(atPath: resourcesPath + "/index.html") && detectedStacks.isEmpty {
            //      detectedStacks.insert(.webWrapper)
            // }
        }

        // --- Priority 5: Infer AppKit/UIKit based on Info.plist and otool (using appToAnalyzeURL) --- 
        if let infoPlist = readInfoPlist(from: appToAnalyzeURL) {
            // Check for Catalyst marker explicitly (might be redundant if Wrapper detected, but good to check)
            if infoPlist["LSRequiresNativeExecution"] as? Bool == true {
                 print("[DetectService] Detected Catalyst via Info.plist.")
                 detectedStacks.insert(.catalyst)
            }
            
            // Refined AppKit Inference: If otool detected Swift, but not SwiftUI,
            // and .appKit wasn't already found via nibs/storyboards, and not Catalyst -> likely AppKit
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

        // --- Final Cleanup & Fallback --- 
        // If both AppKit and UIKit/Catalyst are present (e.g., wrapped app with some AppKit resources?)
        // Prioritize Catalyst/UIKit as the primary environment for wrapped apps.
        if detectedStacks.contains(.catalyst) {
             detectedStacks.remove(.appKit) // Less likely to be the *primary* stack in a wrapped/Catalyst scenario
             print("[DetectService] Prioritizing UIKit/Catalyst over potentially detected AppKit resources due to wrapper/plist.")
        }
        
        if detectedStacks.isEmpty {
            print("[DetectService] No specific stack detected for \(appURL.lastPathComponent), marking as Other.")
            detectedStacks.insert(.other) // Use 'other' instead of 'unknown' from OptionSet
        }

        print("[DetectService] Final detected stacks for \(appURL.lastPathComponent): \(detectedStacks.displayNames.joined(separator: ", "))")
        return detectedStacks
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
