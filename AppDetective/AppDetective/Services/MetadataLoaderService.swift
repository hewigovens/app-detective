import AppKit
import DetectiveCore
import Foundation

enum MetadataLoaderService {
    // Rows draw icons at 44pt; 128px stays sharp on Retina.
    private static let iconPixelSize: CGFloat = 128

    static func metadata(forAppAt path: String, cached: CachedMetadata?) -> CachedMetadata {
        let url = URL(fileURLWithPath: path)
        let fingerprint = fingerprint(of: url)
        if let cached, cached.fingerprint == fingerprint, fingerprint != nil {
            return cached
        }
        return CachedMetadata(
            fingerprint: fingerprint,
            iconData: iconData(forAppAt: path),
            size: BundleMetrics.size(at: url).map(BundleMetrics.format(bytes:))
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
