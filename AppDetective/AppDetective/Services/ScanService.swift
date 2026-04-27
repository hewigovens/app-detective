import Foundation

struct ScanService {
    struct ScanResult {
        let appURLs: [URL]
        let skippedDirectoryURLs: [URL]

        var hasSkippedDirectories: Bool {
            !skippedDirectoryURLs.isEmpty
        }
    }

    enum ScanError: Error, LocalizedError {
        case directoryEnumerationFailed(URL, Error)
        case notADirectory(URL)

        var errorDescription: String? {
            switch self {
            case .directoryEnumerationFailed(let url, let underlyingError):
                return "Failed to read the contents of \(url.path): \(underlyingError.localizedDescription)"
            case .notADirectory(let url):
                return "The selected path is not a folder: \(url.path)"
            }
        }
    }

    /// Scans the given folder URL for .app bundles.
    /// - Parameter folderURL: The URL of the folder to scan. Assumes security scope access has already been started.
    /// - Returns: An array of URLs pointing to the found .app bundles.
    /// - Throws: A ScanError if enumeration fails.
    func scan(folderURL: URL) throws -> [URL] {
        try scanWithDiagnostics(folderURL: folderURL).appURLs
    }

    /// Scans the given folder URL for .app bundles and reports child folders that could not be read.
    /// - Parameter folderURL: The URL of the folder to scan. Assumes security scope access has already been started.
    /// - Returns: A scan result containing found app URLs and skipped child directories.
    /// - Throws: A ScanError if the selected root folder cannot be scanned.
    func scanWithDiagnostics(folderURL: URL) throws -> ScanResult {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw ScanError.notADirectory(folderURL)
        }

        var appURLs: [URL] = []
        var skippedDirectoryURLs: [URL] = []
        try enumerateAndFindApps(
            in: folderURL,
            foundApps: &appURLs,
            skippedDirectoryURLs: &skippedDirectoryURLs,
            isRequiredRoot: true
        )

        // Special case: If scanning /Applications, also scan /System/Applications
        // since macOS Catalina+ stores system apps there
        if folderURL.path == "/Applications" {
            let systemAppsURL = URL(fileURLWithPath: "/System/Applications")
            var systemIsDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: systemAppsURL.path, isDirectory: &systemIsDir), systemIsDir.boolValue {
                try enumerateAndFindApps(
                    in: systemAppsURL,
                    foundApps: &appURLs,
                    skippedDirectoryURLs: &skippedDirectoryURLs,
                    isRequiredRoot: false
                )
            }
        }

        return ScanResult(appURLs: appURLs, skippedDirectoryURLs: skippedDirectoryURLs)
    }

    private func enumerateAndFindApps(
        in directoryURL: URL,
        foundApps: inout [URL],
        skippedDirectoryURLs: inout [URL],
        isRequiredRoot: Bool
    ) throws {
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey], options: [])

            for itemURL in contents {
                // Skip actual hidden files (starting with a dot)
                if itemURL.lastPathComponent.hasPrefix(".") {
                    continue
                }

                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir), isDir.boolValue else {
                    continue
                }

                // Check if it's a .app bundle
                if itemURL.pathExtension.lowercased() == "app" {
                    foundApps.append(itemURL)
                } else {
                    try enumerateAndFindApps(
                        in: itemURL,
                        foundApps: &foundApps,
                        skippedDirectoryURLs: &skippedDirectoryURLs,
                        isRequiredRoot: false
                    )
                }
            }
        } catch {
            if isRequiredRoot {
                throw ScanError.directoryEnumerationFailed(directoryURL, error)
            }
            skippedDirectoryURLs.append(directoryURL)
        }
    }
}
