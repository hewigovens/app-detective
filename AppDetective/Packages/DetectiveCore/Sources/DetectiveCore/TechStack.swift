import Foundation

public struct TechStack: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let swiftUI = TechStack(rawValue: 1 << 0)
    public static let appKit = TechStack(rawValue: 1 << 1)
    public static let catalyst = TechStack(rawValue: 1 << 2)
    public static let electron = TechStack(rawValue: 1 << 3)
    public static let python = TechStack(rawValue: 1 << 4)
    public static let qt = TechStack(rawValue: 1 << 5)
    public static let java = TechStack(rawValue: 1 << 6)
    public static let xamarin = TechStack(rawValue: 1 << 7) // includes .NET MAUI
    public static let flutter = TechStack(rawValue: 1 << 8)
    public static let reactNative = TechStack(rawValue: 1 << 9)
    public static let tauri = TechStack(rawValue: 1 << 10)
    public static let wxWidgets = TechStack(rawValue: 1 << 11)
    public static let cef = TechStack(rawValue: 1 << 12)
    public static let microsoftEdge = TechStack(rawValue: 1 << 13)
    public static let gtk = TechStack(rawValue: 1 << 14)
    public static let gpui = TechStack(rawValue: 1 << 15)
    public static let iced = TechStack(rawValue: 1 << 16)
    public static let other = TechStack(rawValue: 1 << 17)

    public static let native: TechStack = [.swiftUI, .appKit, .catalyst]
    public static let crossPlatform: TechStack = [
        .electron, .cef, .python, .qt, .wxWidgets, .gtk, .java,
        .xamarin, .flutter, .reactNative, .tauri, .gpui, .iced, .microsoftEdge,
    ]

    public static let flagNames: [Int: String] = [
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

    public var displayNames: [String] {
        var names: [String] = []
        for (rawKey, value) in Self.flagNames {
            let key = TechStack(rawValue: rawKey)
            if self.contains(key) {
                names.append(value)
            }
        }
        return names.sorted()
    }

    public var toArray: [TechStack] {
        Self.flagNames.enumerated().map { key, _ in
            TechStack(rawValue: key)
        }
    }
}
