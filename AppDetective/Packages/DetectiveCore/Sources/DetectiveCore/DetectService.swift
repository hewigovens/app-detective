import Foundation
import LSAppCategory

public final class DetectService: Sendable {
    private let signatures: [StackSignature]

    public init(signatures: [StackSignature] = StackSignature.catalog) {
        self.signatures = signatures
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
        if Self.confidentStacks(in: matches).isEmpty, inspector.executableURL != nil {
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

    private static func confidentStacks(in matches: [Match]) -> TechStack {
        let scores = matches.reduce(into: [TechStack: Int]()) { scores, match in
            scores[match.stack, default: 0] += match.rule.confidence.rawValue
        }
        return TechStack(scores.filter { $0.value >= Confidence.reportingThreshold }.keys)
    }

    // Every Mac UI stack sits on AppKit, so report it only when nothing more specific was found.
    private static func resolve(_ stacks: TechStack) -> TechStack {
        let specific = stacks.subtracting(.appKit)
        return specific.isEmpty ? .appKit : specific
    }
}
