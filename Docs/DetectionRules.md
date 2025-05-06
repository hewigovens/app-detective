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
| Java | Java-based applications |
| Xamarin/MAUI | Microsoft's .NET cross-platform UI framework |
| Flutter | Google's UI toolkit for cross-platform apps |
| React Native | JavaScript framework for native mobile apps |
| Tauri | Rust-based framework for building desktop apps |
| Other | Applications with unknown or unidentified frameworks |

## Detection Algorithm Priority

The detection process follows a priority-based approach to determine the technology stack:

### Priority 0: Wrapped iOS App Structure
- Checks for macOS apps that are wrapped iOS applications (Catalyst)
- Looks for a "Wrapper" directory with a "WrappedBundle" symlink
- Strong indicator of UIKit and Catalyst usage

### Priority 1: Pake/Tauri Detection
- Checks for specific markers in Resources directory for Tauri or Pake applications
- Looks for "pake.json" and related files

### Priority 2: Executable Analysis (otool)
- Uses `otool -L` to analyze library dependencies
- Detects:
  - SwiftUI usage
  - Swift libraries (for AppKit/UIKit inference)
  - Python dependencies
  - Qt dependencies

### Priority 3: Frameworks Directory Analysis
- Examines bundled frameworks within the app
- Detects:
  - Electron frameworks
  - Flutter engine
  - .NET/Xamarin assemblies

### Priority 4: Resources Directory Analysis
- Examines the app's resources for framework-specific files
- Detects:
  - AppKit resources (.nib, .storyboardc)
  - Electron resources (app.asar or app directory)
  - Python files (.py, .pyc)
  - Java resources (.jar)
  - Flutter assets (flutter_assets)
  - React Native bundles (main.jsbundle, index.bundle)

### Priority 5: Info.plist and Inference
- Checks Info.plist for Catalyst markers (LSRequiresNativeExecution)
- Infers AppKit usage based on Swift linkage but absence of SwiftUI, UIKit, or Catalyst

### Final Cleanup & Fallback
- Resolves conflicts between detected stacks (e.g., prioritizes UIKit/Catalyst over AppKit when both are detected)
- Falls back to "Other" when no specific stack is detected

## Detection Markers and Heuristics

### Native Apple Frameworks
- **SwiftUI**: Detected by SwiftUI library linkage through otool
- **AppKit**: Detected by .nib/.storyboardc resources or inferred from Swift usage without SwiftUI/Catalyst
- **Catalyst**: Detected by Wrapper structure or LSRequiresNativeExecution in Info.plist (includes UIKit functionality)

### Cross-Platform Frameworks
- **Electron**: Detected by framework presence ("Electron Framework.framework", "Microsoft Edge Framework.framework") or resources (app.asar, app directory)
- **Python**: Detected by Python library linkage or .py/.pyc files
- **Qt**: Detected by Qt library linkage
- **Java**: Detected by .jar files
- **Xamarin/MAUI**: Detected by .NET assemblies
- **Flutter**: Detected by Flutter engine or flutter_assets directory
- **React Native**: Detected by jsbundle files
- **Tauri**: Detected by pake.json or other Tauri markers

## Areas for Improvement

Potential improvements to the detection algorithm:

1. **More Electron Framework Variants**: Add more known Electron framework names as they are discovered
2. **Additional Web Frameworks**: Improve detection of other web-based desktop frameworks
3. **NativeScript Detection**: Add support for NativeScript applications
4. **Progressive Web Apps**: Detection for PWAs packaged as desktop applications
5. **Game Engines**: Detection for Unity, Unreal, or other game engine based apps
6. **Rust-Based Apps**: Improve detection for more Rust frameworks beyond Tauri
7. **PhoneGap/Cordova**: Detection for these hybrid mobile application frameworks
8. **WPF/UWP Applications**: Detection for Windows framework apps ported to Mac
9. **Swift-Backed Electron**: Detection for Electron apps with Swift native modules
10. **Multiple Framework Detection Confidence Levels**: Add confidence metrics to each detection

## Helper Methods

The detector uses several helper methods to facilitate detection:

- `checkExecutableLibraries`: Analyzes executable dependencies
- `readInfoPlist`: Extracts information from Info.plist
- `getExecutableName`: Gets the executable name from Info.plist
- `findExecutable`: Locates the actual executable file
- `directoryContains`: Checks if a directory contains files with specific extensions

---

This document will be updated as the detection algorithms are refined or new technology stack detections are added.
