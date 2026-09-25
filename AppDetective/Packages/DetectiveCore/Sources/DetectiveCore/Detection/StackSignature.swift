import Foundation

/// Everything that identifies one tech stack: a list of rules, each naming a piece of evidence
/// and how much it can be trusted on its own.
public struct StackSignature: Sendable {
    public let stack: TechStack
    public let rules: [Rule]

    public init(_ stack: TechStack, _ rules: [Rule]) {
        self.stack = stack
        self.rules = rules
    }
}

/// How much a single piece of evidence says about a stack.
public enum Confidence: Int, Sendable, Comparable, Codable {
    /// Circumstantial on its own, e.g. a string that could appear in unrelated binaries.
    case weak = 1
    /// Identifies the stack by itself, e.g. its runtime framework is bundled or linked.
    case strong = 2

    /// Total confidence at which a stack is reported: one strong rule or two weak ones.
    static let reportingThreshold = 2

    public static func < (lhs: Confidence, rhs: Confidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct Rule: Sendable {
    public let evidence: Evidence
    public let confidence: Confidence

    public static func strong(_ evidence: Evidence) -> Rule {
        Rule(evidence: evidence, confidence: .strong)
    }

    public static func weak(_ evidence: Evidence) -> Rule {
        Rule(evidence: evidence, confidence: .weak)
    }
}

/// Where a rule looks inside an app bundle.
public enum Evidence: Sendable, CustomStringConvertible {
    /// An item in the bundle's Frameworks directory.
    case framework(Pattern)
    /// An item at the top level of the bundle's Resources directory.
    case resource(Pattern)
    /// An item in the bundle's PlugIns directory.
    case plugIn(Pattern)
    /// A file or directory at this path relative to the bundle root, e.g. `Contents/MonoBundle`.
    case file(String)
    /// The install name of a library linked by the main executable (`otool -L`).
    case linkedLibrary(Pattern)
    /// A printable string inside the main executable (`strings`). Expensive, so these rules
    /// only run when no other rule identified a stack.
    case embeddedString(String)

    public var description: String {
        switch self {
        case let .framework(pattern): "framework \(pattern)"
        case let .resource(pattern): "resource \(pattern)"
        case let .plugIn(pattern): "plug-in \(pattern)"
        case let .file(path): "file \(path)"
        case let .linkedLibrary(pattern): "linked library \(pattern)"
        case let .embeddedString(text): "string \"\(text)\""
        }
    }

    var isEmbeddedString: Bool {
        if case .embeddedString = self { return true }
        return false
    }
}

/// Matches a file name or library install name.
public enum Pattern: Sendable, CustomStringConvertible {
    case exact(String)
    case prefix(String)
    case suffix(String)
    case contains(String)
    /// An `NSRegularExpression` pattern, for names that need more than the simpler cases.
    case regex(String)

    public func matches(_ value: String) -> Bool {
        switch self {
        case let .exact(text): value == text
        case let .prefix(text): value.hasPrefix(text)
        case let .suffix(text): value.hasSuffix(text)
        case let .contains(text): value.contains(text)
        case let .regex(pattern): value.range(of: pattern, options: .regularExpression) != nil
        }
    }

    public var description: String {
        switch self {
        case let .exact(text): "\"\(text)\""
        case let .prefix(text): "\"\(text)…\""
        case let .suffix(text): "\"…\(text)\""
        case let .contains(text): "\"…\(text)…\""
        case let .regex(pattern): "/\(pattern)/"
        }
    }
}
