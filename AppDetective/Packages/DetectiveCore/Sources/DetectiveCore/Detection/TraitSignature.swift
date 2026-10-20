import Foundation

public struct TraitSignature: Sendable {
    public let trait: Trait
    public let rules: [Rule]

    public init(_ trait: Trait, _ rules: [Rule]) {
        self.trait = trait
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
    case entry(in: String, Pattern) // An item in a directory relative to the bundle root, e.g. "Contents/app".
    case embeddedString(String) // In the executable; evaluated only when no UI framework beyond AppKit/UIKit matched.
    case codeString(String) // In the executable, the app's own frameworks, or its extensions.

    public var description: String {
        switch self {
        case let .framework(pattern): "framework \(pattern)"
        case let .resource(pattern): "resource \(pattern)"
        case let .plugIn(pattern): "plug-in \(pattern)"
        case let .file(path): "file \(path)"
        case let .linkedLibrary(pattern): "linked library \(pattern)"
        case let .entry(directory, pattern): "\(directory) entry \(pattern)"
        case let .embeddedString(text): "string \"\(text)\""
        case let .codeString(text): "code string \"\(text)\""
        }
    }

    public var kind: String {
        switch self {
        case .framework: "Framework"
        case .resource: "Resource"
        case .plugIn: "Plug-in"
        case .file: "File"
        case .linkedLibrary: "Linked library"
        case let .entry(directory, _): "Entry in \(directory)"
        case .embeddedString: "Embedded string"
        case .codeString: "String in the app's code"
        }
    }

    enum Pass {
        case bundle
        case code
        case deferred
    }

    var pass: Pass {
        switch self {
        case .codeString: .code
        case .embeddedString: .deferred
        default: .bundle
        }
    }

    var isFramework: Bool {
        if case .framework = self { return true }
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
