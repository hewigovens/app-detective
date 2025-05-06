# App Detective Technology Stack Detection Rules

This document outlines the detection algorithms and rules used by App Detective to identify the technology stack used by macOS applications.

## Supported Technology Stacks

App Detective can currently detect the following technology stacks:

| Technology | Description |
|------------|-------------|
| SwiftUI | Apple's modern declarative UI framework |
| AppKit | Apple's traditional macOS UI framework |
| Catalyst | Technology to bring iOS apps to macOS (incorporates UIKit) |
| Electron | JavaScript framework for cross-platform desktop apps |
| Python | Python-based applications |
| Qt | C++ cross-platform application framework |
| wxWidgets | C++ cross-platform GUI toolkit |
| Java | Java-based applications |
| Xamarin/MAUI | Microsoft's .NET cross-platform UI framework |
| Flutter | Google's UI toolkit for cross-platform apps |
| React Native | JavaScript framework for native mobile apps |
| Tauri | Rust-based framework for building desktop apps |
| Other | Applications with unknown or unidentified frameworks |

## Optimized Detection Algorithm

The detection process is being optimized to prioritize more reliable methods and reduce redundant checks:

### Priority 1: Binary Analysis (otool)
- Uses `otool -L` to analyze library dependencies as the primary detection method
- This is the most reliable way to detect what frameworks an app actually uses
- Detects:
  - **SwiftUI**: Presence of SwiftUI frameworks
  - **Swift**: General Swift library usage
  - **Python**: Libraries containing "Python" or "libpython"
  - **Qt**: Qt framework libraries
  - **wxWidgets**: wxWidgets libraries or entry symbols
  - **Java**: JNI/JVM libraries
  - **Electron**: Presence of Chromium/Electron-related libraries
  - **Rust**: Rust standard libraries (for Tauri apps)

### Priority 2: Structure-Based Detection
- **Catalyst**: Checks for iOS app wrapper structure
  - Detects both root-level WrappedBundle symlinks and those inside Wrapper directory
  - This cannot be reliably detected via otool, so structure check is essential
- **Electron**: Checks for Electron framework presence
  - "Electron Framework.framework", "Microsoft Edge Framework.framework", etc.

### Priority 3: Framework Directory Analysis
- Only performed if otool doesn't provide conclusive results
- Examines bundled frameworks within the app
- Detects:
  - Electron frameworks
  - Flutter engine
  - .NET/Xamarin assemblies

### Priority 4: Selective Resource Analysis
- Only checks for frameworks not already detected by higher priority methods
- Targeted checks for:
  - **AppKit**: .nib/.storyboardc resources (if not detected via otool)
  - **Tauri**: pake.json and related files
  - **Flutter**: flutter_assets directory
  - **React Native**: *.jsbundle files

### Priority 5: Info.plist and Final Inference
- Checks Info.plist for Catalyst markers (LSRequiresNativeExecution)
- Makes final inferences based on collected evidence
- Resolves conflicts between detected stacks
- Falls back to "Other" when no specific stack is detected

## Improved Detection Markers and Heuristics

### Native Apple Frameworks
- **SwiftUI**: 
  - Primary: SwiftUI framework in `otool -L` output
  - Secondary: SwiftUI-specific resource files

- **AppKit**: 
  - Primary: AppKit framework in `otool -L` output
  - Secondary: .nib/.storyboardc resources
  - Tertiary: Swift usage without SwiftUI/Catalyst

- **Catalyst**: 
  - Primary: iOS app wrapper structure (either symlink pattern)
  - Secondary: LSRequiresNativeExecution=true in Info.plist
  - Tertiary: UIKit frameworks in `otool -L` output on macOS app

### Cross-Platform Frameworks
- **Electron**: 
  - Primary: Electron/Chromium libraries in `otool -L` output
  - Secondary: Electron framework presence ("Electron Framework.framework")
  - Tertiary: app.asar or app directory in Resources

- **Python**: 
  - Primary: "libpython" in `otool -L` output
  - Secondary: Python modules or executable
  - Tertiary: .py/.pyc files in Resources

- **Qt**: 
  - Primary: Qt libraries in `otool -L` output (QtCore, QtGui, etc.)
  - Secondary: Qt plugins or resources

- **wxWidgets**: 
  - Primary: wxWidgets libraries in `otool -L` output
  - Secondary: `wx_main` entry symbol in appdata.json or similar files
  - Tertiary: Resources containing wxWidgets-specific files

- **Java**: 
  - Primary: JNI/JVM libraries in `otool -L` output
  - Secondary: .jar files in Resources

- **Xamarin/MAUI**: 
  - Primary: Mono/.NET libraries in `otool -L` output
  - Secondary: .NET assemblies in Frameworks directory

- **Flutter**: 
  - Primary: Flutter engine libraries in `otool -L` output
  - Secondary: Flutter engine in Frameworks
  - Tertiary: flutter_assets directory in Resources

- **React Native**: 
  - Primary: React Native specific libraries in `otool -L` output
  - Secondary: .jsbundle files in Resources

- **Tauri**: 
  - Primary: Rust libraries in `otool -L` output
  - Secondary: pake.json or other Tauri markers

## Areas for Improvement

Potential improvements to the optimized detection algorithm:

1. **Priority-Based Detection**: Implement a system where detections have different confidence levels:
   - High confidence: Binary analysis (`otool -L`) detections
   - Medium confidence: Structure and framework directory checks
   - Low confidence: Resource file analysis

2. **Version Detection**: Extract version information from libraries to provide more detailed insights
   - Detect SwiftUI version
   - Detect Qt version
   - Detect Python version

3. **Additional Technology Stacks**:
   - **Game Engines**: Detection for Unity, Unreal Engine, Godot
   - **Progressive Web Apps**: Detection for PWAs packaged as desktop apps
   - **NativeScript**: Support for NativeScript applications
   - **PhoneGap/Cordova**: Detection for these hybrid frameworks
   - **wxWidgets**: Detection for wxWidgets-based applications (example: Parsec)

4. **Hybrid App Detection**: Better handle apps that use multiple frameworks
   - Swift-backed Electron apps
   - Python apps with Qt interfaces
   - Rust components in otherwise web-based apps

5. **Performance Optimization**: 
   - Cache `otool -L` results
   - Skip filesystem checks when binary analysis is conclusive
   - Use more targeted file lookups instead of directory enumeration

6. **Language Detection**:
   - Separate framework detection from programming language detection
   - Identify multiple languages used in the same app

7. **Metadata Analysis**:
   - Analyze more fields in Info.plist
   - Extract compiler information from binaries
   - Look for build system artifacts

8. **Machine Learning**:
   - Train a model on known app samples to improve detection accuracy
   - Use probabilistic detection instead of binary yes/no

## Improved Helper Methods

The optimized detector would use these helper methods:

- `analyzeExecutable`: Central method for binary analysis using `otool -L`
  - Returns a set of detected frameworks with confidence levels
  - Caches results to avoid redundant analysis

- `checkAppStructure`: Analyzes app bundle structure
  - Detects iOS app wrapping (Catalyst)
  - Handles both root-level and Wrapper-internal symlinks

- `scanFrameworks`: Smart frameworks directory scanner
  - Only runs if binary analysis is inconclusive
  - Detects known framework patterns

- `scanResources`: Targeted resource file scanner
  - Only checks for frameworks not already detected
  - Uses specific file patterns rather than recursive search

- `readInfoPlist`: Enhanced Info.plist analyzer
  - Extracts multiple useful fields beyond just executable name
  - Looks for framework-specific plist keys

- `resolveDetectionConflicts`: Logic to handle conflicting detections
  - Prioritizes higher confidence detections
  - Makes intelligent decisions when multiple frameworks are detected

---

This document will be updated as the detection algorithms are refined or new technology stack detections are added.
