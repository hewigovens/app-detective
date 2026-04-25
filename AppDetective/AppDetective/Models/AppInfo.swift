import DetectiveCore
import Foundation
import LSAppCategory

struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let bundleId: String?
    let techStacks: TechStack
    let category: AppCategory

    var iconData: Data?
    var size: String?
}
