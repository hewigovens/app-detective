import Foundation

public struct Detection: Sendable {
    public let traits: Set<Trait>
    public let possibleTraits: Set<Trait>
    public let matches: [Match]
    // The leaf certificate's common name, codesign's first Authority line.
    public let signer: String?
}

public struct Match: Sendable {
    public let trait: Trait
    public let rule: Rule
    public let item: String
}
