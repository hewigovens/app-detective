import Foundation

public struct Detection: Sendable {
    public let stacks: TechStack
    public let possibleStacks: TechStack
    public let matches: [Match]
}

public struct Match: Sendable, CustomStringConvertible {
    public let stack: TechStack
    public let rule: Rule
    public let item: String

    public var description: String {
        "\(stack.displayName): \(rule.evidence) → \(item) [\(rule.confidence)]"
    }
}
