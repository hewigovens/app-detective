import Foundation

public enum TraitKind: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case ui
    case language
    case renderer
    case updater

    public var name: String {
        switch self {
        case .ui: "UI"
        case .language: "Language"
        case .renderer: "Renderer"
        case .updater: "Updater"
        }
    }

    public var pluralName: String {
        switch self {
        case .ui: "UI Frameworks"
        case .language: "Languages"
        case .renderer: "Renderers"
        case .updater: "Updaters"
        }
    }
}

// Declaration order is display order.
public enum Trait: String, CaseIterable, Codable, Comparable, Identifiable, Sendable, CustomStringConvertible {
    case swiftUI, appKit, uiKit, catalyst
    case electron, cef, microsoftEdge, flutter, qt, reactNative, java, python
    case xamarin, avalonia, compose, tauri, wxWidgets, gpui, iced, egui, slint, wails, fyne, gtk
    case unity, unreal, xojo
    case other
    case swift, objectiveC, rust, go
    case wgpu
    case appStore, sparkle, squirrel, tauriUpdater

    public var id: String { rawValue }

    public var description: String { name }

    public var kind: TraitKind {
        switch self {
        case .swift, .objectiveC, .rust, .go: .language
        case .wgpu: .renderer
        case .appStore, .sparkle, .squirrel, .tauriUpdater: .updater
        default: .ui
        }
    }

    // Every other UI framework runs on top of these, so they are reported only as a fallback.
    var isBaseline: Bool {
        self == .appKit || self == .uiKit
    }

    public var name: String {
        switch self {
        case .swiftUI: "SwiftUI"
        case .appKit: "AppKit"
        case .uiKit: "UIKit (iOS)" // iOS apps running on Apple silicon
        case .catalyst: "Catalyst"
        case .electron: "Electron"
        case .cef: "Chromium Embedded Framework"
        case .microsoftEdge: "Microsoft Edge"
        case .flutter: "Flutter"
        case .qt: "Qt"
        case .reactNative: "React Native"
        case .java: "Java"
        case .python: "Python"
        case .xamarin: "Xamarin/MAUI"
        case .avalonia: "Avalonia"
        case .compose: "Compose Multiplatform"
        case .tauri: "Tauri"
        case .wxWidgets: "wxWidgets"
        case .gpui: "GPUI"
        case .iced: "Iced"
        case .egui: "egui"
        case .slint: "Slint"
        case .wails: "Wails"
        case .fyne: "Fyne"
        case .gtk: "GTK"
        case .unity: "Unity"
        case .unreal: "Unreal Engine"
        case .xojo: "Xojo"
        case .other: "Other"
        case .swift: "Swift"
        case .objectiveC: "Objective-C"
        case .rust: "Rust"
        case .go: "Go"
        case .wgpu: "wgpu"
        case .appStore: "App Store"
        case .sparkle: "Sparkle"
        case .squirrel: "Squirrel"
        case .tauriUpdater: "Tauri Updater"
        }
    }

    public static func < (lhs: Trait, rhs: Trait) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

extension Set<Trait> {
    public func of(_ kind: TraitKind) -> Set<Trait> {
        filter { $0.kind == kind }
    }

    public var names: [String] {
        sorted().map(\.name)
    }

    public var namesByKind: [TraitKind: [String]] {
        Dictionary(grouping: sorted(), by: \.kind).mapValues { $0.map(\.name) }
    }
}
