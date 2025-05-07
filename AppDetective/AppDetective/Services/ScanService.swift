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
        let fileManager = FileManager.default

        do {
            // Enumerate the directory contents, skipping subdirectories for now (level 1)
            let contents = try fileManager.contentsOfDirectory(at: folderURL,
                                                               includingPropertiesForKeys: [.isDirectoryKey, .isApplicationKey],
                                                               options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) // Only top level

            for itemURL in contents {
                // Check if it's an application bundle (.app extension)
                if itemURL.pathExtension.lowercased() == "app" {
                    // Simple check: verify it's actually a directory (bundles are directories)
                    var itemIsDir: ObjCBool = false
                    if fileManager.fileExists(atPath: itemURL.path, isDirectory: &itemIsDir), itemIsDir.boolValue {
                        appURLs.append(itemURL)
                        print("Found app: \(itemURL.lastPathComponent)")
                    }
                }
            }
        } catch {
            print("Error enumerating directory \(folderURL.path): \(error)")
            throw ScanError.directoryEnumerationFailed(error)
        }

        return appURLs
    }
}
