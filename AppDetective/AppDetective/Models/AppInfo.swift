import Foundation

/// Represents information about a detected application.
struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let techStack: TechStack
}
