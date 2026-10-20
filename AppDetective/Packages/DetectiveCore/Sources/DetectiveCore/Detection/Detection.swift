import Foundation

public struct Detection: Sendable {
    public let traits: Set<Trait>
    public let possibleTraits: Set<Trait>
    public let matches: [Match]
}

public struct Match: Sendable, CustomStringConvertible {
    public let trait: Trait
    public let rule: Rule
    public let item: String

    public var description: String {
        "\(trait.name): \(rule.evidence) → \(item) [\(rule.confidence)]"
    }
}
