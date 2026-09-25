import Foundation
import LSAppCategory

/// Detects the UI technology stack and category of application bundles.
public final class DetectService: Sendable {
    private let signatures: [StackSignature]

    /// - Parameter signatures: Rules to evaluate; defaults to the built-in catalog.
    public init(signatures: [StackSignature] = StackSignature.catalog) {
        self.signatures = signatures
    }

    // MARK: - Public API

    /// Analyzes an app bundle and returns the tech stacks it is built with.
    /// - Parameter appURL: URL of the `.app` bundle.
    /// - Returns: The detected stacks, or `.other` if the bundle can't be analyzed.
    public func detectStack(for appURL: URL) async -> TechStack {
        detect(appURL).stacks
    }

    /// Analyzes an app bundle and returns the detected stacks with the evidence for each.
    ///
    /// Rules that inspect the bundle's files and linked libraries run first. Embedded-string
    /// rules scan the whole executable, so they run only when nothing else was identified.
    /// Standard macOS bundles and iOS apps wrapped for Apple silicon Macs are both supported.
    /// - Parameter appURL: URL of the `.app` bundle.
    public func detect(_ appURL: URL) -> Detection {
        // Bundle resolves the executable the same way LaunchServices does, including bundles
        // without CFBundleExecutable (named after the bundle) and iOS `WrappedBundle` layouts.
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

    /// Reads the app category from `LSApplicationCategoryType`, falling back to the
    /// App Store metadata that accompanies iOS apps installed on the Mac.
    /// - Parameter appURL: URL of the `.app` bundle.
    /// - Returns: The app category, or `.other` if none is declared.
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

    // MARK: - Evaluation

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

    /// Every Mac UI stack sits on AppKit, so AppKit is reported only when nothing more specific
    /// was found — including when nothing was found at all.
    private static func resolve(_ stacks: TechStack) -> TechStack {
        let specific = stacks.subtracting(.appKit)
        return specific.isEmpty ? .appKit : specific
    }
}
