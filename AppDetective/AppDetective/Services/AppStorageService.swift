import Foundation

class AppStorageService {
    static let shared = AppStorageService()
    private let folderURLBookmarkKey = "selectedFolderURLBookmark"

    private init() {}

    func saveFolderURLBookmark(url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: folderURLBookmarkKey)
            print("[AppStorageService] Saved bookmark for URL: \(url.path)")
        } catch {
            print("[AppStorageService] Error saving bookmark data: \(error.localizedDescription)")
        }
    }

    func loadFolderURLFromBookmark() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: folderURLBookmarkKey) else {
            print("[AppStorageService] No bookmark data found.")
            return nil
        }

        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

            if isStale {
                print("[AppStorageService] Bookmark data is stale for URL: \(url.path). Attempting to refresh by re-saving.")
                saveFolderURLBookmark(url: url)
            }

            print("[AppStorageService] Loaded URL from bookmark: \(url.path)")
            return url
        } catch {
            print("[AppStorageService] Error resolving bookmark data: \(error.localizedDescription). Clearing invalid bookmark.")
            UserDefaults.standard.removeObject(forKey: folderURLBookmarkKey)
            return nil
        }
    }

    func clearFolderURLBookmark() {
        UserDefaults.standard.removeObject(forKey: folderURLBookmarkKey)
        print("[AppStorageService] Cleared folder URL bookmark.")
    }
}
