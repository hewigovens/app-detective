import AppKit
import DetectiveCore
import Foundation
import LSAppCategory

struct CachedApp: Codable, Sendable {
    let fingerprint: Date? // Info.plist modification date; changes when the app is updated.
    let detectorVersion: String
    let bundleId: String?
    let stacks: TechStack
    let possibleStacks: TechStack
    let evidence: [StackEvidence]
    let category: AppCategory
    let iconData: Data?
    let size: String?
}

struct StackEvidence: Codable, Hashable, Sendable {
    let stack: String
    let rule: String
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
        return CachedApp(
            fingerprint: fingerprint,
            detectorVersion: detectService.version,
            bundleId: Bundle(url: url)?.bundleIdentifier,
            stacks: detection.stacks,
            possibleStacks: detection.possibleStacks,
            evidence: detection.matches.map {
                StackEvidence(
                    stack: $0.stack.displayName,
                    rule: $0.rule.evidence.description,
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
