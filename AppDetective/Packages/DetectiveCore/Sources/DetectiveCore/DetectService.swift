import Foundation
import LSAppCategory

public final class DetectService: Sendable {
    // Bump when detection logic outside the catalog changes; catalog edits change `version` on their own.
    private static let engineVersion = 12

    private let signatures: [TraitSignature]

    /// Identifies these rules, so results saved under a different version can be discarded.
    public let version: String

    public init(signatures: [TraitSignature] = TraitSignature.catalog) {
        self.signatures = signatures
        let ruleText = signatures
            .flatMap { signature in signature.rules.map { "\(signature.trait.rawValue) \($0.evidence) \($0.confidence.rawValue)" } }
            .joined(separator: "\n")
        version = "\(Self.engineVersion)-\(String(Self.fnv1a(ruleText), radix: 16))"
    }

    public func detect(_ appURL: URL) -> Detection {
        // Bundle applies LaunchServices' executable fallbacks (no CFBundleExecutable, WrappedBundle).
        guard let bundle = Bundle(url: appURL) else {
            return Detection(traits: [.other], possibleTraits: [], matches: [], signer: nil)
        }
        let inspector = BundleInspector(bundle: bundle)

        var matches = evaluate(inspector, .bundle)
        // A UI framework's bundled runtime (Electron's Chromium, for one) is not the app's own code.
        inspector.excludedFrameworks = Set(matches.filter { $0.trait.kind == .ui && $0.rule.evidence.isFramework }.map(\.item))
        matches += evaluate(inspector, .code)
        // Embedded strings are circumstantial, so they count only when no UI framework beyond the baseline was found.
        if Self.toolkits(in: Self.confidentTraits(in: matches)).isEmpty {
            matches += evaluate(inspector, .embedded)
        }

        let confident = Self.confidentTraits(in: matches)
        let possible = Set(matches.map(\.trait)).subtracting(confident)
        // Signing and bundle contents say nothing about how a bundle without an executable is built.
        let traits: Set<Trait> = if inspector.executableURL == nil, confident.of([.ui, .language, .renderer]).isEmpty {
            confident.union([.other])
        } else {
            Self.resolve(confident)
        }
        return Detection(traits: traits, possibleTraits: possible.subtracting(traits), matches: matches, signer: inspector.signer)
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

    private func evaluate(_ inspector: BundleInspector, _ pass: Evidence.Pass) -> [Match] {
        signatures.flatMap { signature in
            signature.rules
                .filter { $0.evidence.pass == pass }
                .compactMap { rule in
                    inspector.match(rule.evidence).map { Match(trait: signature.trait, rule: rule, item: $0) }
                }
        }
    }

    // Stable across launches, unlike `hashValue`.
    private static func fnv1a(_ text: String) -> UInt64 {
        text.utf8.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }

    private static func confidentTraits(in matches: [Match]) -> Set<Trait> {
        let scores = matches.reduce(into: [Trait: Int]()) { scores, match in
            scores[match.trait, default: 0] += match.rule.confidence.rawValue
        }
        return Set(scores.filter { $0.value >= Confidence.reportingThreshold }.keys)
    }

    // The baseline UI is reported only when nothing more specific was found, and not for apps that draw their
    // own UI with a renderer. Apple frameworks without another language mean Objective-C; SwiftUI always
    // comes with Swift. Every other kind is reported as matched.
    private static func resolve(_ traits: Set<Trait>) -> Set<Trait> {
        let toolkits = toolkits(in: traits)
        let renderers = traits.of(.renderer)
        let ui: Set<Trait> = if !toolkits.isEmpty {
            toolkits
        } else if !renderers.isEmpty {
            []
        } else {
            [traits.contains(.uiKit) ? .uiKit : .appKit]
        }
        var languages = traits.of(.language)
        if languages.isEmpty, !ui.isEmpty, ui.isSubset(of: [.appKit, .uiKit, .catalyst]) {
            languages = [.objectiveC]
        }
        return ui.union(languages).union(traits.filter { $0.kind != .ui && $0.kind != .language })
    }

    private static func toolkits(in traits: Set<Trait>) -> Set<Trait> {
        traits.of(.ui).filter { !$0.isBaseline }
    }
}
