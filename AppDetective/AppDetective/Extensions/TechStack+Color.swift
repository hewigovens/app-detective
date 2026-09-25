import DetectiveCore
import SwiftUI

extension TechStack {
    var mainColor: Color {
        switch self {
        case .swiftUI: return Color.orange
        case .appKit: return Color.blue
        case .catalyst: return Color.purple
        case .uiKit: return Color.indigo
        case .swift: return Color(hex: "#F05138")
        case .objectiveC: return Color(hex: "#8E8E93")
        case .electron: return Color.cyan
        case .cef: return Color(hex: "#3498db")
        case .python: return Color(hex: "#336c9d")
        case .qt: return Color(hex: "#4CAF50")
        case .wxWidgets: return Color(hex: "#7B61D9")
        case .gtk: return Color(hex: "#729FCF")
        case .java: return Color.red
        case .xamarin: return Color(hex: "#3498DB")
        case .flutter: return Color.teal
        case .reactNative: return Color(hex: "#61DAFB")
        case .tauri: return Color(hex: "#FFC131")
        case .gpui: return Color(hex: "#FF6B6B")
        case .iced: return Color(hex: "#A0D2DB")
        case .microsoftEdge: return Color(hex: "#0078D4")
        case .unity: return Color(hex: "#222C37")
        case .unreal: return Color(hex: "#0E1128")
        case .compose: return Color(hex: "#4285F4")
        case .avalonia: return Color(hex: "#8B44AC")
        case .wails: return Color(hex: "#DF0000")
        case .fyne: return Color(hex: "#00ADD8")
        case .xojo: return Color(hex: "#C9302C")
        case .egui: return Color(hex: "#E0B84C")
        case .slint: return Color(hex: "#2379F4")
        case .other: return Color.gray
        default:
            if self.contains(.swiftUI) { return Color.orange }
            if self.contains(.appKit) { return Color.blue }
            return Color.gray
        }
    }
}
