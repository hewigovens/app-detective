import Foundation
import SwiftUI

struct TechStack: OptionSet, Codable, Hashable {
    let rawValue: Int

    static let swiftUI = TechStack(rawValue: 1 << 0)
    static let appKit = TechStack(rawValue: 1 << 1)
    static let catalyst = TechStack(rawValue: 1 << 2)
    static let electron = TechStack(rawValue: 1 << 3)
    static let python = TechStack(rawValue: 1 << 4)
    static let qt = TechStack(rawValue: 1 << 5)
    static let java = TechStack(rawValue: 1 << 6)
    static let xamarin = TechStack(rawValue: 1 << 7) // .NET MAUI falls here too
    static let flutter = TechStack(rawValue: 1 << 8)
    static let reactNative = TechStack(rawValue: 1 << 9)
    static let tauri = TechStack(rawValue: 1 << 10)
    static let wxWidgets = TechStack(rawValue: 1 << 11)
    static let cef = TechStack(rawValue: 1 << 12)
    static let microsoftEdge = TechStack(rawValue: 1 << 13)
    static let gtk = TechStack(rawValue: 1 << 14)
    static let gpui = TechStack(rawValue: 1 << 15)
    static let iced = TechStack(rawValue: 1 << 16)
    static let other = TechStack(rawValue: 1 << 17)

    static let native: TechStack = [.swiftUI, .appKit, .catalyst]
    static let crossPlatform: TechStack = [
        .electron, .cef, .python, .qt, .wxWidgets, .gtk, .java,
        .xamarin, .flutter, .reactNative, .tauri, .gpui, .iced, .microsoftEdge,
    ]

    static let flagNames: [Int: String] = [
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
        Self.cef.rawValue: "Chromium Embedded Framework",
        Self.gpui.rawValue: "GPUI",
        Self.iced.rawValue: "Iced",
        Self.microsoftEdge.rawValue: "Microsoft Edge",
        Self.gtk.rawValue: "GTK",
        Self.other.rawValue: "Other",
    ]

    // Prioritized main color
    var mainColor: Color {
        switch self {
        case .swiftUI: return Color.orange
        case .appKit: return Color.blue
        case .catalyst: return Color.purple
        case .electron: return Color.cyan
        case .cef: return Color(hex: "#3498db") // A specific blue for CEF
        case .python: return Color(hex: "#336c9d")
        case .qt: return Color(hex: "#4CAF50") // Qt's official green
        case .wxWidgets: return Color(hex: "#7B61D9") // wxWidgets purple
        case .gtk: return Color(hex: "#729FCF") // GTK blue
        case .java: return Color.red
        case .xamarin: return Color(hex: "#3498DB") // Xamarin blue
        case .flutter: return Color.teal
        case .reactNative: return Color(hex: "#61DAFB") // React's blue
        case .tauri: return Color(hex: "#FFC131") // Tauri's yellow
        case .gpui: return Color(hex: "#FF6B6B") // A reddish color for GPUI
        case .iced: return Color(hex: "#A0D2DB") // A light blue for Iced
        case .microsoftEdge: return Color(hex: "#0078D4") // Microsoft's blue
        case .other: return Color.gray
        default:
            if self.contains(.swiftUI) { return Color.orange }
            if self.contains(.appKit) { return Color.blue }
            return Color.gray
        }
    }

    // Computed property to get names of contained stacks
    var displayNames: [String] {
        var names: [String] = []
        for (rawKey, value) in Self.flagNames {
            let key = TechStack(rawValue: rawKey)
            if self.contains(key) {
                names.append(value)
            }
        }
        return names.sorted()
    }

    var toArray: [TechStack] {
        Self.flagNames.enumerated().map { key, _ in
            TechStack(rawValue: key)
        }
    }
}
