import Foundation

public enum TraitKind: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case ui
    case language
    case renderer
    case graphics
    case distribution
    case updater
    case security
    case background

    public var name: String {
        switch self {
        case .ui: "UI"
        case .language: "Language"
        case .renderer: "Renderer"
        case .graphics: "Graphics"
        case .distribution: "Distribution"
        case .updater: "Updater"
        case .security: "Security"
        case .background: "Background"
        }
    }

    public var pluralName: String {
        switch self {
        case .ui: "UI Frameworks"
        case .language: "Languages"
        case .renderer: "Renderers"
        case .graphics: "Graphics APIs"
        case .distribution: "Distribution"
        case .updater: "Updaters"
        case .security: "Security"
        case .background: "Background Items"
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
    case metal, openGL, vulkan
    case appStore, testFlight, developerID, apple, adHoc
    case sparkle, squirrel, tauriUpdater
    case sandbox, hardenedRuntime, notarized
    case loginItem, launchAgent, launchDaemon, privilegedHelper, systemExtension

    public var id: String { rawValue }

    public var description: String { name }

    public var kind: TraitKind {
        switch self {
        case .swift, .objectiveC, .rust, .go: .language
        case .wgpu: .renderer
        case .metal, .openGL, .vulkan: .graphics
        case .appStore, .testFlight, .developerID, .apple, .adHoc: .distribution
        case .sparkle, .squirrel, .tauriUpdater: .updater
        case .sandbox, .hardenedRuntime, .notarized: .security
        case .loginItem, .launchAgent, .launchDaemon, .privilegedHelper, .systemExtension: .background
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
        case .metal: "Metal"
        case .openGL: "OpenGL"
        case .vulkan: "Vulkan"
        case .appStore: "App Store"
        case .testFlight: "TestFlight"
        case .developerID: "Developer ID"
        case .apple: "Apple"
        case .adHoc: "Ad-hoc Signed"
        case .sparkle: "Sparkle"
        case .squirrel: "Squirrel"
        case .tauriUpdater: "Tauri Updater"
        case .sandbox: "App Sandbox"
        case .hardenedRuntime: "Hardened Runtime"
        case .notarized: "Notarized"
        case .loginItem: "Login Item"
        case .launchAgent: "Launch Agent"
        case .launchDaemon: "Launch Daemon"
        case .privilegedHelper: "Privileged Helper"
        case .systemExtension: "System Extension"
        }
    }

    private static let order = Dictionary(uniqueKeysWithValues: allCases.enumerated().map { ($1, $0) })

    public static func < (lhs: Trait, rhs: Trait) -> Bool {
        order[lhs]! < order[rhs]!
    }
}

extension Set<Trait> {
    public func of(_ kind: TraitKind) -> Set<Trait> {
        of([kind])
    }

    public func of(_ kinds: Set<TraitKind>) -> Set<Trait> {
        filter { kinds.contains($0.kind) }
    }

    public var names: [String] {
        sorted().map(\.name)
    }

    public var namesByKind: [TraitKind: [String]] {
        Dictionary(grouping: sorted(), by: \.kind).mapValues { $0.map(\.name) }
    }
}
