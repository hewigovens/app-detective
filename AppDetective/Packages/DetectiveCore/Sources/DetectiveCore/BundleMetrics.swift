import Foundation

extension Bundle {
    public var shortVersion: String? {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    public var build: String? {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
}

public enum BundleMetrics {
    public static func size(at url: URL) -> Int64? {
        guard let enumerator = FileManager.default.enumerator(
            at: url.resolvingSymlinksInPath(),
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

    // The build alone when it repeats the version.
    public static func version(short: String?, build: String?) -> String? {
        switch (short, build) {
        case let (short?, build?) where short != build: "\(short) (\(build))"
        case let (short?, _): short
        case let (nil, build?): build
        case (nil, nil): nil
        }
    }

    public static func format(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
