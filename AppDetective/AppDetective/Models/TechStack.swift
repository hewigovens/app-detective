import Foundation
import SwiftUI

struct TechStack: OptionSet, Codable, Hashable {
    let rawValue: Int

    static let swiftUI     = TechStack(rawValue: 1 << 0)
    static let uiKit       = TechStack(rawValue: 1 << 1)
    static let appKit      = TechStack(rawValue: 1 << 2)
    static let catalyst    = TechStack(rawValue: 1 << 3)
    static let electron    = TechStack(rawValue: 1 << 4)
    static let python      = TechStack(rawValue: 1 << 5)
    static let qt          = TechStack(rawValue: 1 << 6)
    static let java        = TechStack(rawValue: 1 << 7)
    static let xamarin     = TechStack(rawValue: 1 << 8) // .NET MAUI falls here too
    static let flutter     = TechStack(rawValue: 1 << 9)
    static let reactNative = TechStack(rawValue: 1 << 10)
    static let tauri       = TechStack(rawValue: 1 << 11) // Added for pake/Tauri
    static let webWrapper  = TechStack(rawValue: 1 << 12) // Generic Web View
    static let other       = TechStack(rawValue: 1 << 13) // Explicitly marked as other

    static let native: TechStack = [.swiftUI, .uiKit, .appKit, .catalyst]
    static let crossPlatform: TechStack = [.electron, .qt, .java, .xamarin, .flutter, .reactNative, .tauri, .python] // Python often used with others

    // String representation for each flag
    var flagNames: [Int: String] {
        [
            Self.swiftUI.rawValue: "SwiftUI",
            Self.uiKit.rawValue: "UIKit",
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
            Self.webWrapper.rawValue: "Web Wrapper",
            Self.other.rawValue: "Other"
        ]
    }

    // Computed property to get names of contained stacks
    var displayNames: [String] {
        var names: [String] = []
        for (key, name) in flagNames {
             if self.contains(TechStack(rawValue: key)) {
                 names.append(name)
             }
        }
        // If empty or only contains 'other', return 'Unknown'
        if names.isEmpty || (names.count == 1 && self.contains(.other)) {
             return ["Unknown"]
        }
         // Filter out 'Other' if other specific stacks are present
         if names.count > 1 {
              names.removeAll { $0 == "Other" }
         }
        return names.sorted() // Sort for consistent display
    }

    // Prioritized main color
    var mainColor: Color {
        // Prioritize native stacks first
        if self.contains(.swiftUI) { return .blue }
        if self.contains(.uiKit) { return .orange }
        if self.contains(.appKit) { return .purple }
        if self.contains(.catalyst) { return .teal }
        // Then cross-platform
        if self.contains(.electron) { return .indigo }
        if self.contains(.flutter) { return .pink }
        if self.contains(.reactNative) { return .mint }
        if self.contains(.tauri) { return .brown }
        if self.contains(.qt) { return .green }
        if self.contains(.xamarin) { return .cyan }
        if self.contains(.python) { return Color(red: 0.2, green: 0.4, blue: 0.6) } // Python blue/yellow logo colors mixed
        if self.contains(.java) { return .red }
        // Then generic web
        if self.contains(.webWrapper) { return .yellow }
        // Fallback
        if self.contains(.other) { return .gray }
        return .gray // Default if empty or unknown
    }
}
