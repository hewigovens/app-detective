import DetectiveCore
import SwiftUI

extension TechStack {
    var mainColor: Color {
        switch self {
        case .swiftUI: return Color.orange
        case .appKit: return Color.blue
        case .catalyst: return Color.purple
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
        case .other: return Color.gray
        default:
            if self.contains(.swiftUI) { return Color.orange }
            if self.contains(.appKit) { return Color.blue }
            return Color.gray
        }
    }
}
