import Foundation

class DiskCacheService {
    private let iconCacheFileName = "iconCache.plist"
    private let sizeCacheFileName = "sizeCache.plist"

    private var cacheDirectoryURL: URL? {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("[DiskCache] Error: Could not find Application Support directory.")
            return nil
        }
        // Create a subdirectory specific to this app to avoid cluttering Application Support
        let bundleID = Bundle.main.bundleIdentifier ?? "com.unknown.appdetective"
        let appCacheDirectory = appSupportURL.appendingPathComponent(bundleID)

        // Create the directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: appCacheDirectory, withIntermediateDirectories: true, attributes: nil)
            return appCacheDirectory
        } catch {
            print("[DiskCache] Error: Could not create cache directory at \(appCacheDirectory.path): \(error)")
            return nil
        }
    }

    // MARK: - Loading

    func loadIconCache() -> [String: Data]? {
        guard let directoryURL = cacheDirectoryURL else { return nil }
        let fileURL = directoryURL.appendingPathComponent(iconCacheFileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[DiskCache] Icon cache file does not exist at \(fileURL.path)")
            return nil // No cache file exists yet
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = PropertyListDecoder()
            let cache = try decoder.decode([String: Data].self, from: data)
            print("[DiskCache] Successfully loaded icon cache with \(cache.count) items from \(fileURL.path)")
            return cache
        } catch {
            print("[DiskCache] Error loading icon cache from \(fileURL.path): \(error)")
            return nil
        }
    }

    func loadSizeCache() -> [String: String]? {
        guard let directoryURL = cacheDirectoryURL else { return nil }
        let fileURL = directoryURL.appendingPathComponent(sizeCacheFileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[DiskCache] Size cache file does not exist at \(fileURL.path)")
            return nil // No cache file exists yet
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = PropertyListDecoder()
            let cache = try decoder.decode([String: String].self, from: data)
            print("[DiskCache] Successfully loaded size cache with \(cache.count) items from \(fileURL.path)")
            return cache
        } catch {
            print("[DiskCache] Error loading size cache from \(fileURL.path): \(error)")
            return nil
        }
    }

    // MARK: - Saving

    func saveIconCache(_ cache: [String: Data]) {
        guard let directoryURL = cacheDirectoryURL else { return }
        let fileURL = directoryURL.appendingPathComponent(iconCacheFileName)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary // More efficient

        do {
            let data = try encoder.encode(cache)
            try data.write(to: fileURL, options: [.atomic]) // Atomic write for safety
            print("[DiskCache] Successfully saved icon cache (\(cache.count) items) to \(fileURL.path)")
        } catch {
            print("[DiskCache] Error saving icon cache to \(fileURL.path): \(error)")
        }
    }

    func saveSizeCache(_ cache: [String: String]) {
        guard let directoryURL = cacheDirectoryURL else { return }
        let fileURL = directoryURL.appendingPathComponent(sizeCacheFileName)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary // More efficient

        do {
            let data = try encoder.encode(cache)
            try data.write(to: fileURL, options: [.atomic]) // Atomic write for safety
            print("[DiskCache] Successfully saved size cache (\(cache.count) items) to \(fileURL.path)")
        } catch {
            print("[DiskCache] Error saving size cache to \(fileURL.path): \(error)")
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
                print("[DiskCache] Cleared icon cache file at \(iconFileURL.path)")
            }
            if FileManager.default.fileExists(atPath: sizeFileURL.path) {
                try FileManager.default.removeItem(at: sizeFileURL)
                print("[DiskCache] Cleared size cache file at \(sizeFileURL.path)")
            }
        } catch {
            print("[DiskCache] Error clearing cache files: \(error)")
        }
    }
}
