import Foundation
import LSAppCategory

/// Represents information about a detected application.
struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let techStacks: TechStack
    let category: AppCategory

    // Added for cache
    var iconData: Data?
    var size: String?
}
