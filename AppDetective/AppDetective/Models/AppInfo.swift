import DetectiveCore
import Foundation
import LSAppCategory

struct AppInfo: Identifiable, Hashable, Sendable {
    let name: String
    let path: String
    let bundleId: String?
    let techStacks: TechStack
    let category: AppCategory

    var iconData: Data?
    var size: String?

    var id: String { path }
}

// A String-backed enum that LSAppCategory doesn't mark Sendable.
extension AppCategory: @retroactive @unchecked Sendable {}
