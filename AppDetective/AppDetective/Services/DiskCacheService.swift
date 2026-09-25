import Foundation
import OSLog

struct DiskCacheService {
    private static let cacheFileName = "appCache.plist"
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

    func load() -> [String: CachedApp] {
        removeLegacyCaches()
        guard let fileURL = cacheFileURL, let data = try? Data(contentsOf: fileURL) else {
            return [:]
        }
        do {
            return try PropertyListDecoder().decode([String: CachedApp].self, from: data)
        } catch {
            Logger.cache.error("Failed to decode app cache: \(error.localizedDescription)")
            return [:]
        }
    }

    func save(_ cache: [String: CachedApp]) {
        guard let fileURL = cacheFileURL else { return }
        let liveEntries = cache.filter { FileManager.default.fileExists(atPath: $0.key) }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        do {
            try encoder.encode(liveEntries).write(to: fileURL, options: .atomic)
        } catch {
            Logger.cache.error("Failed to save app cache: \(error.localizedDescription)")
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
