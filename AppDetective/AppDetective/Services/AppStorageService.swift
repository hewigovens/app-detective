import Foundation

class AppStorageService {
    static let shared = AppStorageService()
    private let folderURLBookmarkKey = "selectedFolderURLBookmark"

    private init() {}

    func saveFolderURLBookmark(url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: folderURLBookmarkKey)
        } catch {
            print("[AppStorageService] Error saving bookmark: \(error.localizedDescription)")
        }
    }

    func loadFolderURLFromBookmark() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: folderURLBookmarkKey) else {
            return nil
        }

        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

            if isStale {
                saveFolderURLBookmark(url: url)
            }

            return url
        } catch {
            print("[AppStorageService] Error resolving bookmark: \(error.localizedDescription)")
            UserDefaults.standard.removeObject(forKey: folderURLBookmarkKey)
            return nil
        }
    }

    func clearFolderURLBookmark() {
        UserDefaults.standard.removeObject(forKey: folderURLBookmarkKey)
    }
}
