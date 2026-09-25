import Foundation
import OSLog

struct CachedMetadata: Codable, Sendable {
    let fingerprint: Date? // Info.plist modification date; changes when the app is updated.
    let iconData: Data?
    let size: String?
}

struct DiskCacheService {
    private static let cacheFileName = "metadataCache.plist"
    // Written to Application Support by earlier versions.
    private static let legacyFileNames = ["iconCache.plist", "sizeCache.plist"]

    private let bundleID = Bundle.main.bundleIdentifier ?? Constants.BundleId

    private var cacheFileURL: URL? {
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directoryURL = cachesURL.appendingPathComponent(bundleID)
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            Logger.cache.error("Failed to create cache directory: \(error.localizedDescription)")
            return nil
        }
        return directoryURL.appendingPathComponent(Self.cacheFileName)
    }

    func load() -> [String: CachedMetadata] {
        removeLegacyCaches()
        guard let fileURL = cacheFileURL, let data = try? Data(contentsOf: fileURL) else {
            return [:]
        }
        do {
            return try PropertyListDecoder().decode([String: CachedMetadata].self, from: data)
        } catch {
            Logger.cache.error("Failed to decode metadata cache: \(error.localizedDescription)")
            return [:]
        }
    }

    func save(_ cache: [String: CachedMetadata]) {
        guard let fileURL = cacheFileURL else { return }
        let liveEntries = cache.filter { FileManager.default.fileExists(atPath: $0.key) }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        do {
            try encoder.encode(liveEntries).write(to: fileURL, options: .atomic)
        } catch {
            Logger.cache.error("Failed to save metadata cache: \(error.localizedDescription)")
        }
    }

    func clear() {
        guard let fileURL = cacheFileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func removeLegacyCaches() {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        for name in Self.legacyFileNames {
            try? FileManager.default.removeItem(at: appSupportURL.appendingPathComponent(bundleID).appendingPathComponent(name))
        }
    }
}
