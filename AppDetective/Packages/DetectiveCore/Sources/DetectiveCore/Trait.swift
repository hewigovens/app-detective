import Foundation

public enum TraitKind: String, CaseIterable, Codable, Sendable {
    case ui
    case language
    case renderer

    public var name: String {
        switch self {
        case .ui: "UI"
        case .language: "Language"
        case .renderer: "Renderer"
        }
    }

    public var pluralName: String {
        switch self {
        case .ui: "UI Frameworks"
        case .language: "Languages"
        case .renderer: "Renderers"
        }
    }
}

public struct Trait: Hashable, Codable, Sendable, Identifiable, CustomStringConvertible {
    public let id: String
    public let kind: TraitKind
    public let name: String

    init(_ id: String, _ kind: TraitKind, _ name: String) {
        self.id = id
        self.kind = kind
        self.name = name
    }

    public var description: String { name }

    public static let swiftUI = Trait("swiftUI", .ui, "SwiftUI")
    public static let appKit = Trait("appKit", .ui, "AppKit")
    public static let uiKit = Trait("uiKit", .ui, "UIKit (iOS)") // iOS apps running on Apple silicon
    public static let catalyst = Trait("catalyst", .ui, "Catalyst")
    public static let electron = Trait("electron", .ui, "Electron")
    public static let cef = Trait("cef", .ui, "Chromium Embedded Framework")
    public static let microsoftEdge = Trait("microsoftEdge", .ui, "Microsoft Edge")
    public static let flutter = Trait("flutter", .ui, "Flutter")
    public static let qt = Trait("qt", .ui, "Qt")
    public static let reactNative = Trait("reactNative", .ui, "React Native")
    public static let java = Trait("java", .ui, "Java")
    public static let python = Trait("python", .ui, "Python")
    public static let xamarin = Trait("xamarin", .ui, "Xamarin/MAUI") // includes .NET MAUI
    public static let avalonia = Trait("avalonia", .ui, "Avalonia")
    public static let compose = Trait("compose", .ui, "Compose Multiplatform")
    public static let tauri = Trait("tauri", .ui, "Tauri")
    public static let wxWidgets = Trait("wxWidgets", .ui, "wxWidgets")
    public static let gpui = Trait("gpui", .ui, "GPUI")
    public static let iced = Trait("iced", .ui, "Iced")
    public static let egui = Trait("egui", .ui, "egui")
    public static let slint = Trait("slint", .ui, "Slint")
    public static let wails = Trait("wails", .ui, "Wails")
    public static let fyne = Trait("fyne", .ui, "Fyne")
    public static let gtk = Trait("gtk", .ui, "GTK")
    public static let unity = Trait("unity", .ui, "Unity")
    public static let unreal = Trait("unreal", .ui, "Unreal Engine")
    public static let xojo = Trait("xojo", .ui, "Xojo")
    public static let other = Trait("other", .ui, "Other")

    public static let swift = Trait("swift", .language, "Swift")
    public static let objectiveC = Trait("objectiveC", .language, "Objective-C")
    public static let rust = Trait("rust", .language, "Rust")
    public static let go = Trait("go", .language, "Go")

    public static let wgpu = Trait("wgpu", .renderer, "wgpu")

    // Display order: by kind, then native before cross-platform.
    public static let all: [Trait] = [
        .swiftUI, .appKit, .uiKit, .catalyst,
        .electron, .cef, .microsoftEdge, .flutter, .qt, .reactNative, .java, .python,
        .xamarin, .avalonia, .compose, .tauri, .wxWidgets, .gpui, .iced, .egui, .slint, .wails, .fyne, .gtk,
        .unity, .unreal, .xojo,
        .other,
        .swift, .objectiveC, .rust, .go,
        .wgpu,
    ]

    public static func sorted(_ traits: Set<Trait>) -> [Trait] {
        all.filter(traits.contains)
    }

    public static func names(_ traits: Set<Trait>) -> [String] {
        sorted(traits).map(\.name)
    }

    public static func namesByKind(_ traits: Set<Trait>) -> [String: [String]] {
        Dictionary(grouping: sorted(traits), by: \.kind.rawValue).mapValues { $0.map(\.name) }
    }
}
