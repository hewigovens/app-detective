import DetectiveCore
import SwiftUI

extension Trait {
    var color: Color {
        Self.colors[id] ?? .gray
    }

    private static let colors: [String: Color] = [
        Trait.swiftUI.id: .orange,
        Trait.appKit.id: .blue,
        Trait.catalyst.id: .purple,
        Trait.uiKit.id: .indigo,
        Trait.electron.id: .cyan,
        Trait.cef.id: Color(hex: "#3498db"),
        Trait.python.id: Color(hex: "#336c9d"),
        Trait.qt.id: Color(hex: "#4CAF50"),
        Trait.wxWidgets.id: Color(hex: "#7B61D9"),
        Trait.gtk.id: Color(hex: "#729FCF"),
        Trait.java.id: .red,
        Trait.xamarin.id: Color(hex: "#3498DB"),
        Trait.flutter.id: .teal,
        Trait.reactNative.id: Color(hex: "#61DAFB"),
        Trait.tauri.id: Color(hex: "#FFC131"),
        Trait.gpui.id: Color(hex: "#FF6B6B"),
        Trait.iced.id: Color(hex: "#A0D2DB"),
        Trait.microsoftEdge.id: Color(hex: "#0078D4"),
        Trait.unity.id: Color(hex: "#222C37"),
        Trait.unreal.id: Color(hex: "#0E1128"),
        Trait.compose.id: Color(hex: "#4285F4"),
        Trait.avalonia.id: Color(hex: "#8B44AC"),
        Trait.wails.id: Color(hex: "#DF0000"),
        Trait.fyne.id: Color(hex: "#00ADD8"),
        Trait.xojo.id: Color(hex: "#C9302C"),
        Trait.egui.id: Color(hex: "#E0B84C"),
        Trait.slint.id: Color(hex: "#2379F4"),
        Trait.swift.id: Color(hex: "#F05138"),
        Trait.objectiveC.id: Color(hex: "#8E8E93"),
        Trait.rust.id: Color(hex: "#DEA584"),
        Trait.go.id: Color(hex: "#007D9C"),
        Trait.wgpu.id: Color(hex: "#5C7CFA"),
    ]
}
