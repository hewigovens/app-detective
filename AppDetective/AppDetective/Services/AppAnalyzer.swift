import AppKit
import DetectiveCore
import Foundation
import LSAppCategory

struct CachedApp: Codable, Sendable {
    let fingerprint: Date? // Info.plist modification date; changes when the app is updated.
    let detectorVersion: String
    let bundleId: String?
    let version: String?
    let traits: Set<Trait>
    let possibleTraits: Set<Trait>
    let evidence: [TraitEvidence]
    let category: AppCategory
    let iconData: Data?
    let size: String?
}

struct TraitEvidence: Codable, Hashable, Sendable {
    let trait: String
    let rule: String
    let label: String
    let item: String
    let isStrong: Bool
}

enum AppAnalyzer {
    // Rows draw icons at 44pt; 128px stays sharp on Retina.
    private static let iconPixelSize: CGFloat = 128

    static func analyze(_ url: URL, cached: CachedApp?, detectService: DetectService) -> CachedApp {
        let fingerprint = fingerprint(of: url)
        let isUnchanged = fingerprint != nil && cached?.fingerprint == fingerprint
        if let cached, isUnchanged, cached.detectorVersion == detectService.version {
            return cached
        }

        let detection = detectService.detect(url)
        let bundle = Bundle(url: url)
        return CachedApp(
            fingerprint: fingerprint,
            detectorVersion: detectService.version,
            bundleId: bundle?.bundleIdentifier,
            version: BundleMetrics.version(short: bundle?.shortVersion, build: bundle?.build),
            traits: detection.traits,
            possibleTraits: detection.possibleTraits,
            evidence: detection.matches.map {
                TraitEvidence(
                    trait: $0.trait.name,
                    rule: $0.rule.evidence.description,
                    label: $0.rule.evidence.label,
                    item: $0.item,
                    isStrong: $0.rule.confidence == .strong
                )
            },
            category: detectService.extractCategory(from: url),
            iconData: isUnchanged ? cached?.iconData : iconData(forAppAt: url.path),
            size: isUnchanged ? cached?.size : BundleMetrics.size(at: url).map(BundleMetrics.format(bytes:))
        )
    }

    private static func fingerprint(of appURL: URL) -> Date? {
        let candidates = ["Contents/Info.plist", "WrappedBundle/Info.plist", "Info.plist"]
            .map { appURL.appendingPathComponent($0) } + [appURL]
        for url in candidates {
            if let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                return date
            }
        }
        return nil
    }

    private static func iconData(forAppAt path: String) -> Data? {
        let pixels = Int(iconPixelSize)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        // Graphics state is per thread, so this is safe off the main thread.
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSWorkspace.shared.icon(forFile: path)
            .draw(in: NSRect(x: 0, y: 0, width: iconPixelSize, height: iconPixelSize))
        NSGraphicsContext.restoreGraphicsState()

        return bitmap.representation(using: .png, properties: [:])
    }
}
