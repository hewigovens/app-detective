import Foundation

struct ScanService {
    enum ScanError: Error, LocalizedError {
        case directoryEnumerationFailed(Error)
        case notADirectory(URL)

        var errorDescription: String? {
            switch self {
            case .directoryEnumerationFailed(let underlyingError):
                return "Failed to read the contents of the folder: \(underlyingError.localizedDescription)"
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
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw ScanError.notADirectory(folderURL)
        }

        var appURLs: [URL] = []
        try enumerateAndFindApps(in: folderURL, foundApps: &appURLs)

        // Special case: If scanning /Applications, also scan /System/Applications
        // since macOS Catalina+ stores system apps there
        if folderURL.path == "/Applications" {
            let systemAppsURL = URL(fileURLWithPath: "/System/Applications")
            var systemIsDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: systemAppsURL.path, isDirectory: &systemIsDir), systemIsDir.boolValue {
                try enumerateAndFindApps(in: systemAppsURL, foundApps: &appURLs)
            }
        }

        return appURLs
    }

    private func enumerateAndFindApps(in directoryURL: URL, foundApps: inout [URL]) throws {
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)

            for itemURL in contents {
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir), isDir.boolValue else {
                    continue
                }

                // Check if it's a .app bundle
                if itemURL.pathExtension.lowercased() == "app" {
                    foundApps.append(itemURL)
                } else {
                    try enumerateAndFindApps(in: itemURL, foundApps: &foundApps)
                }
            }
        } catch {
            throw ScanError.directoryEnumerationFailed(error)
        }
    }
}