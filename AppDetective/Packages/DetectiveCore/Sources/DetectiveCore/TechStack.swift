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
    public static let uiKit = TechStack(rawValue: 1 << 18) // iOS apps running on Apple silicon
    public static let swift = TechStack(rawValue: 1 << 19)
    public static let objectiveC = TechStack(rawValue: 1 << 20)
    public static let unity = TechStack(rawValue: 1 << 21)
    public static let unreal = TechStack(rawValue: 1 << 22)
    public static let compose = TechStack(rawValue: 1 << 23)
    public static let avalonia = TechStack(rawValue: 1 << 24)
    public static let wails = TechStack(rawValue: 1 << 25)
    public static let fyne = TechStack(rawValue: 1 << 26)
    public static let xojo = TechStack(rawValue: 1 << 27)
    public static let egui = TechStack(rawValue: 1 << 28)
    public static let slint = TechStack(rawValue: 1 << 29)

    public static let native: TechStack = [.swiftUI, .appKit, .catalyst, .uiKit]
    // Reported only with AppKit or UIKit, to tell Swift and Objective-C apps apart.
    public static let languages: TechStack = [.swift, .objectiveC]
    public static let crossPlatform: TechStack = [
        .electron, .cef, .python, .qt, .wxWidgets, .gtk, .java,
        .xamarin, .flutter, .reactNative, .tauri, .gpui, .iced, .microsoftEdge,
        .unity, .unreal, .compose, .avalonia, .wails, .fyne, .xojo, .egui, .slint,
    ]

    public static let allStacks: [TechStack] = [
        .swiftUI, .appKit, .uiKit, .catalyst, .swift, .objectiveC,
        .electron, .cef, .microsoftEdge, .flutter, .qt, .reactNative, .java, .python,
        .xamarin, .avalonia, .compose, .tauri, .wxWidgets, .gpui, .iced, .egui, .slint, .wails, .fyne, .gtk,
        .unity, .unreal, .xojo,
        .other,
    ]

    public static let flagNames: [Int: String] = [
        Self.swiftUI.rawValue: "SwiftUI",
        Self.appKit.rawValue: "AppKit",
        Self.catalyst.rawValue: "Catalyst",
        Self.uiKit.rawValue: "UIKit (iOS)",
        Self.swift.rawValue: "Swift",
        Self.objectiveC.rawValue: "Objective-C",
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
        Self.unity.rawValue: "Unity",
        Self.unreal.rawValue: "Unreal Engine",
        Self.compose.rawValue: "Compose Multiplatform",
        Self.avalonia.rawValue: "Avalonia",
        Self.wails.rawValue: "Wails",
        Self.fyne.rawValue: "Fyne",
        Self.xojo.rawValue: "Xojo",
        Self.egui.rawValue: "egui",
        Self.slint.rawValue: "Slint",
        Self.other.rawValue: "Other",
    ]

    public var displayName: String {
        Self.flagNames[rawValue] ?? "Unknown"
    }

    public var displayNames: [String] {
        Self.flagNames
            .filter { contains(TechStack(rawValue: $0.key)) }
            .map(\.value)
            .sorted()
    }
}
