import Foundation

public struct StackSignature: Sendable {
    public let stack: TechStack
    public let rules: [Rule]

    public init(_ stack: TechStack, _ rules: [Rule]) {
        self.stack = stack
        self.rules = rules
    }
}

public enum Confidence: Int, Sendable {
    case weak = 1
    case strong = 2

    static let reportingThreshold = 2
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

public enum Evidence: Sendable, CustomStringConvertible {
    case framework(Pattern)
    case resource(Pattern)
    case plugIn(Pattern)
    case file(String) // Relative to the bundle root, e.g. "Contents/MonoBundle".
    case linkedLibrary(Pattern)
    case embeddedString(String) // Runs `strings`, so only evaluated when no cross-platform stack matched.

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

public enum Pattern: Sendable, CustomStringConvertible {
    case exact(String)
    case prefix(String)
    case suffix(String)
    case contains(String)
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
