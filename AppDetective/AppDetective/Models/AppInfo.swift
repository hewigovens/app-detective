import DetectiveCore
import Foundation
import LSAppCategory

struct AppInfo: Identifiable, Hashable, Sendable {
    let name: String
    let path: String
    let bundleId: String?
    let techStacks: TechStack
    var possibleStacks: TechStack = []
    var evidence: [StackEvidence] = []
    let category: AppCategory

    var iconData: Data?
    var size: String?

    var id: String { path }
}

extension AppInfo {
    init(url: URL, analysis: CachedApp) {
        self.init(
            name: url.deletingPathExtension().lastPathComponent,
            path: url.path,
            bundleId: analysis.bundleId,
            techStacks: analysis.stacks,
            possibleStacks: analysis.possibleStacks,
            evidence: analysis.evidence,
            category: analysis.category,
            iconData: analysis.iconData,
            size: analysis.size
        )
    }
}

// A String-backed enum that LSAppCategory doesn't mark Sendable.
extension AppCategory: @retroactive @unchecked Sendable {}
