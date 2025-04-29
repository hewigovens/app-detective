import Foundation

enum TechStack: String, CaseIterable {
    case electron = "Electron"
    case swiftUI = "SwiftUI"
    case uiKitAppKit = "UIKit/AppKit"
    case python = "Python"
    case webWrapper = "Web Wrapper (Generic)" // For basic web views
    case unknown = "Unknown"
    // Add more as needed (React Native, Catalyst, etc.)
}

struct DetectService {

    let fileManager = FileManager.default

    /// Detects the likely primary technology stack of a given .app bundle.
    /// - Parameter appURL: The URL of the .app bundle.
    /// - Returns: A `TechStack` enum value.
    func detectStack(for appURL: URL) -> TechStack {
        // Ensure security scope access is active if needed when calling this.

        // --- Electron Check --- 
        // Look for the Electron framework or typical Electron app structure.
        let electronFrameworkPath = appURL.appendingPathComponent("Contents/Frameworks/Electron Framework.framework")
        let electronAsarPath = appURL.appendingPathComponent("Contents/Resources/app.asar") // Common Electron packaging
        if fileManager.fileExists(atPath: electronFrameworkPath.path) || fileManager.fileExists(atPath: electronAsarPath.path) {
            return .electron
        }

        // --- SwiftUI Check --- 
        // More complex: Requires analyzing binaries or specific plist keys.
        // Simplistic check: Look for Swift libraries, especially SwiftUI-related ones.
        // This is a weak heuristic, as many apps might use Swift.
        let swiftLibsPath = appURL.appendingPathComponent("Contents/Frameworks/libswiftSwiftUI.dylib") // Example
        if fileManager.fileExists(atPath: swiftLibsPath.path) {
            // Could also check Info.plist for specific keys if needed
            return .swiftUI // Tentative guess
        }
        
        // --- AppKit/UIKit Check (Native) ---
        // Check for compiled Swift/Objective-C code and absence of Electron markers.
        // Look for the main executable.
        let infoPlistPath = appURL.appendingPathComponent("Contents/Info.plist")
        let macosPath = appURL.appendingPathComponent("Contents/MacOS")
        if let plistDict = NSDictionary(contentsOf: infoPlistPath), 
           let executableName = plistDict["CFBundleExecutable"] as? String {
            let executablePath = macosPath.appendingPathComponent(executableName)
            if fileManager.fileExists(atPath: executablePath.path) {
                 // This is a very broad check, essentially confirming it's a standard macOS app.
                 // If not Electron or SwiftUI (by our simple checks), assume native AppKit.
                 // More sophisticated checks would look at linked frameworks.
                 return .uiKitAppKit // Default native guess
            }
        }

        // --- Python Check --- 
        // Look for Python scripts, frameworks (e.g., Python.framework), or common packagers (PyInstaller, briefcase).
        let pythonFrameworkPath = appURL.appendingPathComponent("Contents/Frameworks/Python.framework")
        let mainPyPath = appURL.appendingPathComponent("Contents/Resources/main.py") // Common entry point
        // Add checks for specific packager structures if needed
        if fileManager.fileExists(atPath: pythonFrameworkPath.path) || fileManager.fileExists(atPath: mainPyPath.path) {
            return .python
        }

        // --- Basic Web Wrapper Check ---
        // Look for only HTML/JS/CSS files in Resources, minimal native code.
        let resourcesPath = appURL.appendingPathComponent("Contents/Resources")
        if let contents = try? fileManager.contentsOfDirectory(atPath: resourcesPath.path),
           contents.contains(where: { $0.lowercased().hasSuffix(".html") }) && 
           !fileManager.fileExists(atPath: electronFrameworkPath.path) /* Not Electron */ {
            return .webWrapper
        }

        // --- Fallback --- 
        return .unknown
    }
}
