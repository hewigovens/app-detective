import DetectiveCore
import SwiftUI

extension Trait {
    var color: Color {
        switch self {
        case .swiftUI: .orange
        case .appKit: .blue
        case .uiKit: .indigo
        case .catalyst: .purple
        case .electron: .cyan
        case .cef, .xamarin: Color(hex: "#3498DB")
        case .microsoftEdge: Color(hex: "#0078D4")
        case .flutter: .teal
        case .qt: Color(hex: "#4CAF50")
        case .reactNative: Color(hex: "#61DAFB")
        case .java: .red
        case .python: Color(hex: "#336C9D")
        case .avalonia: Color(hex: "#8B44AC")
        case .compose: Color(hex: "#4285F4")
        case .tauri, .tauriUpdater: Color(hex: "#FFC131")
        case .wxWidgets: Color(hex: "#7B61D9")
        case .gpui: Color(hex: "#FF6B6B")
        case .iced: Color(hex: "#A0D2DB")
        case .egui: Color(hex: "#E0B84C")
        case .slint: Color(hex: "#2379F4")
        case .wails: Color(hex: "#DF0000")
        case .fyne: Color(hex: "#00ADD8")
        case .gtk: Color(hex: "#729FCF")
        case .unity: Color(hex: "#222C37")
        case .unreal: Color(hex: "#0E1128")
        case .xojo: Color(hex: "#C9302C")
        case .other: .gray
        case .swift: Color(hex: "#F05138")
        case .objectiveC: Color(hex: "#8E8E93")
        case .rust: Color(hex: "#B7410E")
        case .go: Color(hex: "#007D9C")
        case .wgpu: Color(hex: "#5C7CFA")
        case .appStore: Color(hex: "#0D96F6")
        case .sparkle: Color(hex: "#E8A33D")
        case .squirrel: Color(hex: "#A0785A")
        }
    }
}
