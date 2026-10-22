import DetectiveCore
import Foundation
import LSAppCategory

struct AppInfo: Identifiable, Hashable, Sendable {
    let name: String
    let path: String
    let bundleId: String?
    var version: String?
    let traits: Set<Trait>
    var possibleTraits: Set<Trait> = []
    var evidence: [TraitEvidence] = []
    let category: AppCategory

    var iconData: Data?
    var size: String?

    var id: String { path }

    // Fallbacks such as AppKit and Objective-C, which no rule matched.
    var inferredTraits: Set<Trait> {
        traits.filter { trait in !evidence.contains { $0.trait == trait.name } }
    }
}

extension AppInfo {
    init(url: URL, analysis: CachedApp) {
        self.init(
            name: url.deletingPathExtension().lastPathComponent,
            path: url.path,
            bundleId: analysis.bundleId,
            version: analysis.version,
            traits: analysis.traits,
            possibleTraits: analysis.possibleTraits,
            evidence: analysis.evidence,
            category: analysis.category,
            iconData: analysis.iconData,
            size: analysis.size
        )
    }
}

// A String-backed enum that LSAppCategory doesn't mark Sendable.
extension AppCategory: @retroactive @unchecked Sendable {}
