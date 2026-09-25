import Foundation
import LSAppCategory

public final class DetectService: Sendable {
    // Bump when detection logic outside the catalog changes; catalog edits change `version` on their own.
    private static let engineVersion = 2

    private let signatures: [StackSignature]

    /// Identifies these rules, so results saved under a different version can be discarded.
    public let version: String

    public init(signatures: [StackSignature] = StackSignature.catalog) {
        self.signatures = signatures
        let ruleText = signatures
            .flatMap { signature in signature.rules.map { "\(signature.stack.rawValue) \($0.evidence) \($0.confidence.rawValue)" } }
            .joined(separator: "\n")
        version = "\(Self.engineVersion)-\(String(Self.fnv1a(ruleText), radix: 16))"
    }

    public func detectStack(for appURL: URL) async -> TechStack {
        detect(appURL).stacks
    }

    public func detect(_ appURL: URL) -> Detection {
        // Bundle applies LaunchServices' executable fallbacks (no CFBundleExecutable, WrappedBundle).
        guard let bundle = Bundle(url: appURL) else {
            return Detection(stacks: .other, possibleStacks: [], matches: [])
        }
        let inspector = BundleInspector(bundle: bundle)

        var matches = evaluate(inspector, embeddedStrings: false)
        if Self.confidentStacks(in: matches).isDisjoint(with: .crossPlatform), inspector.executableURL != nil {
            matches += evaluate(inspector, embeddedStrings: true)
        }

        let confident = Self.confidentStacks(in: matches)
        let possible = TechStack(matches.map(\.stack)).subtracting(confident)
        let stacks: TechStack = if confident.isEmpty, inspector.executableURL == nil {
            .other
        } else {
            Self.resolve(confident)
        }
        return Detection(stacks: stacks, possibleStacks: possible.subtracting(stacks), matches: matches)
    }

    public func extractCategory(from appURL: URL) -> AppCategory {
        if let categoryType = Bundle(url: appURL)?.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String {
            return AppCategory(string: categoryType)
        }

        var metadataURLs = [appURL.appendingPathComponent("Wrapper/iTunesMetadata.plist")]
        let parentURL = appURL.deletingLastPathComponent()
        if parentURL.lastPathComponent == "Wrapper" {
            metadataURLs.append(parentURL.appendingPathComponent("iTunesMetadata.plist"))
        }

        for metadataURL in metadataURLs {
            if
                let metadata = NSDictionary(contentsOf: metadataURL),
                let categoryType = (metadata["categories"] as? [String])?.first
            {
                return AppCategory(string: categoryType)
            }
        }

        return .other
    }

    private func evaluate(_ inspector: BundleInspector, embeddedStrings: Bool) -> [Match] {
        signatures.flatMap { signature in
            signature.rules
                .filter { $0.evidence.isEmbeddedString == embeddedStrings }
                .compactMap { rule in
                    inspector.match(rule.evidence).map { Match(stack: signature.stack, rule: rule, item: $0) }
                }
        }
    }

    // Stable across launches, unlike `hashValue`.
    private static func fnv1a(_ text: String) -> UInt64 {
        text.utf8.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }

    private static func confidentStacks(in matches: [Match]) -> TechStack {
        let scores = matches.reduce(into: [TechStack: Int]()) { scores, match in
            scores[match.stack, default: 0] += match.rule.confidence.rawValue
        }
        return TechStack(scores.filter { $0.value >= Confidence.reportingThreshold }.keys)
    }

    // AppKit and UIKit underlie every other UI stack, so report them only when nothing more specific was found.
    private static func resolve(_ stacks: TechStack) -> TechStack {
        let specific = stacks.subtracting([.appKit, .uiKit])
        if !specific.isEmpty {
            return specific
        }
        return stacks.contains(.uiKit) ? .uiKit : .appKit
    }
}
