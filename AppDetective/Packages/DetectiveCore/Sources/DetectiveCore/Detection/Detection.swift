import Foundation

public struct Detection: Sendable {
    public let traits: Set<Trait>
    public let possibleTraits: Set<Trait>
    public let matches: [Match]
}

public struct Match: Sendable {
    public let trait: Trait
    public let rule: Rule
    public let item: String
}
