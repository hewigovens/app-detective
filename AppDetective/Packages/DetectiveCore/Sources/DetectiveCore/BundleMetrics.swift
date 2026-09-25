import Foundation

public enum BundleMetrics {
    public static func size(at url: URL) -> Int64? {
        let resolved = url.resolvingSymlinksInPath()
        let keys: Set<URLResourceKey> = [.totalFileSizeKey, .totalFileAllocatedSizeKey]
        if let values = try? resolved.resourceValues(forKeys: keys) {
            if let total = values.totalFileSize { return Int64(total) }
            if let allocated = values.totalFileAllocatedSize { return Int64(allocated) }
        }
        guard let enumerator = FileManager.default.enumerator(
            at: resolved,
            includingPropertiesForKeys: [.fileSizeKey],
            options: []
        ) else {
            return nil
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    public static func format(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
