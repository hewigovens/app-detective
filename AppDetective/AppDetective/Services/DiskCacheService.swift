import Foundation

class DiskCacheService {
    private let iconCacheFileName = "iconCache.plist"
    private let sizeCacheFileName = "sizeCache.plist"

    private var cacheDirectoryURL: URL? {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let bundleID = Bundle.main.bundleIdentifier ?? "com.unknown.appdetective"
        let appCacheDirectory = appSupportURL.appendingPathComponent(bundleID)

        do {
            try FileManager.default.createDirectory(at: appCacheDirectory, withIntermediateDirectories: true, attributes: nil)
            return appCacheDirectory
        } catch {
            print("[DiskCache] Error creating cache directory: \(error)")
            return nil
        }
    }

    // MARK: - Loading

    func loadIconCache() -> [String: Data]? {
        guard let directoryURL = cacheDirectoryURL else { return nil }
        let fileURL = directoryURL.appendingPathComponent(iconCacheFileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            return try PropertyListDecoder().decode([String: Data].self, from: data)
        } catch {
            print("[DiskCache] Error loading icon cache: \(error)")
            return nil
        }
    }

    func loadSizeCache() -> [String: String]? {
        guard let directoryURL = cacheDirectoryURL else { return nil }
        let fileURL = directoryURL.appendingPathComponent(sizeCacheFileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            return try PropertyListDecoder().decode([String: String].self, from: data)
        } catch {
            print("[DiskCache] Error loading size cache: \(error)")
            return nil
        }
    }

    // MARK: - Saving

    func saveIconCache(_ cache: [String: Data]) {
        guard let directoryURL = cacheDirectoryURL else { return }
        let fileURL = directoryURL.appendingPathComponent(iconCacheFileName)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary

        do {
            let data = try encoder.encode(cache)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("[DiskCache] Error saving icon cache: \(error)")
        }
    }

    func saveSizeCache(_ cache: [String: String]) {
        guard let directoryURL = cacheDirectoryURL else { return }
        let fileURL = directoryURL.appendingPathComponent(sizeCacheFileName)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary

        do {
            let data = try encoder.encode(cache)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("[DiskCache] Error saving size cache: \(error)")
        }
    }

    // MARK: - Clearing

    func clearAllCaches() {
        guard let directoryURL = cacheDirectoryURL else { return }
        let iconFileURL = directoryURL.appendingPathComponent(iconCacheFileName)
        let sizeFileURL = directoryURL.appendingPathComponent(sizeCacheFileName)

        do {
            if FileManager.default.fileExists(atPath: iconFileURL.path) {
                try FileManager.default.removeItem(at: iconFileURL)
            }
            if FileManager.default.fileExists(atPath: sizeFileURL.path) {
                try FileManager.default.removeItem(at: sizeFileURL)
            }
        } catch {
            print("[DiskCache] Error clearing caches: \(error)")
        }
    }
}
