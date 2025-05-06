# App Detective

App Detective is a macOS application that analyzes and identifies the technology stacks used by macOS applications. It helps developers and users understand the frameworks and technologies behind their installed applications.

## Features

- **Stack Detection**: Automatically detects the technology stack used by macOS applications
- **Multiple Framework Support**: Identifies both native Apple frameworks and cross-platform technologies
- **Visual Identification**: Color-coded results for quick visual identification of different technologies

## Supported Technology Stacks

App Detective can detect the following technology stacks:

### Native Apple Frameworks
- SwiftUI
- AppKit
- Catalyst

### Cross-Platform Frameworks
- Electron
- Python
- Qt
- Java
- Xamarin/MAUI
- Flutter
- React Native
- Tauri

## How It Works

App Detective uses a prioritized detection algorithm to identify the technology stack:

1. Examines app structure for Catalyst/iOS markers
2. Checks for specific framework indicators
3. Analyzes executable dependencies using `otool`
4. Inspects bundled frameworks
5. Scans resource files for framework-specific assets
6. Checks Info.plist and infers technologies based on available information

For more detailed information about the detection rules and algorithms, see [DetectionRules.md](Docs/DetectionRules.md).

## Development

App Detective is built with Swift and SwiftUI. The core detection logic is in the `DetectService.swift` file.

## Future Improvements

- Support for more technology stacks and frameworks
- Improved detection accuracy
- Confidence levels for detected technologies
- Performance optimizations for scanning large numbers of applications
