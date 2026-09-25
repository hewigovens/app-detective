import Foundation

/// The outcome of analyzing one app bundle, including the evidence behind it.
public struct Detection: Sendable {
    /// Stacks with enough evidence to report. Never empty: falls back to AppKit, or `.other`
    /// when the bundle has no executable.
    public let stacks: TechStack
    /// Stacks with some evidence, but not enough to report.
    public let possibleStacks: TechStack
    /// Every rule that matched, in catalog order.
    public let matches: [Match]
}

/// A rule that matched, with the item that satisfied it.
public struct Match: Sendable, CustomStringConvertible {
    public let stack: TechStack
    public let rule: Rule
    /// The framework, library, file, or string that was found.
    public let item: String

    public var description: String {
        "\(stack.displayName): \(rule.evidence) → \(item) [\(rule.confidence)]"
    }
}
