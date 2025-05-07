import Foundation
import SwiftUI

struct TechStack: OptionSet, Codable, Hashable {
    let rawValue: Int

    static let swiftUI = TechStack(rawValue: 1 << 0)
    static let appKit = TechStack(rawValue: 1 << 2)
    static let catalyst = TechStack(rawValue: 1 << 3)
    static let electron = TechStack(rawValue: 1 << 4)
    static let python = TechStack(rawValue: 1 << 5)
    static let qt = TechStack(rawValue: 1 << 6)
    static let java = TechStack(rawValue: 1 << 7)
    static let xamarin = TechStack(rawValue: 1 << 8) // .NET MAUI falls here too
    static let flutter = TechStack(rawValue: 1 << 9)
    static let reactNative = TechStack(rawValue: 1 << 10)
    static let tauri = TechStack(rawValue: 1 << 11) // Added for pake/Tauri
    static let wxWidgets = TechStack(rawValue: 1 << 12) // Added for wxWidgets
    static let cef = TechStack(rawValue: 1 << 13) // Chromium Embedded Framework

    static let native: TechStack = [.swiftUI, .appKit, .catalyst]
    static let crossPlatform: TechStack = [.electron, .qt, .java, .xamarin, .flutter, .reactNative, .tauri, .python, .wxWidgets, .cef] // Python often used with others

    // String representation for each flag
    var flagNames: [Int: String] {
        [
            Self.swiftUI.rawValue: "SwiftUI",
            Self.appKit.rawValue: "AppKit",
            Self.catalyst.rawValue: "Catalyst",
            Self.electron.rawValue: "Electron",
            Self.python.rawValue: "Python",
            Self.qt.rawValue: "Qt",
            Self.java.rawValue: "Java",
            Self.xamarin.rawValue: "Xamarin/MAUI",
            Self.flutter.rawValue: "Flutter",
            Self.reactNative.rawValue: "React Native",
            Self.tauri.rawValue: "Tauri",
            Self.wxWidgets.rawValue: "wxWidgets",
            Self.cef.rawValue: "Chromium Embedded Framework"
        ]
    }

    // Computed property to get names of contained stacks
    var displayNames: [String] {
        var names: [String] = []
        for (key, name) in self.flagNames {
            if self.contains(TechStack(rawValue: key)) {
                names.append(name)
            }
        }
        // If empty, return 'AppKit' as fallback
        if names.isEmpty {
            return ["AppKit"] // AppKit as default fallback when nothing else detected
        }
        // Remove AppKit from display if any other framework is detected
        // Since almost all Mac apps link against AppKit, we only show it when it's the only framework
        if names.count > 1 && names.contains("AppKit") {
            names.removeAll { $0 == "AppKit" }
        }
        return names.sorted() // Sort for consistent display
    }

    // Prioritized main color
    var mainColor: Color {
        // Prioritize native stacks first
        if self.contains(.swiftUI) { return .blue }
        if self.contains(.appKit) { return .purple }
        if self.contains(.catalyst) { return .teal }
        // Then cross-platform
        if self.contains(.electron) { return .indigo }
        if self.contains(.flutter) { return .pink }
        if self.contains(.reactNative) { return .mint }
        if self.contains(.tauri) { return .brown }
        if self.contains(.qt) { return .green }
        if self.contains(.wxWidgets) { return .orange }
        if self.contains(.xamarin) { return .cyan }
        if self.contains(.python) { return Color(red: 0.2, green: 0.4, blue: 0.6) }
        if self.contains(.java) { return .red }
        if self.contains(.cef) { return Color(red: 0.0, green: 0.6, blue: 0.9) } // Chromium blue
        // Fallback - appKit purple
        return .purple // Default is AppKit color
    }
}
