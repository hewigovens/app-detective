import DetectiveCore
import Foundation
import SwiftUI

@MainActor
@Observable
final class ContentViewModel {
    private static let concurrencyLimit = 8
    private static let publishBatchSize = 8

    private static let folderPathKey = "scanFolderPath"
    private static let legacyBookmarkKey = "selectedFolderBookmark"

    var isLoading = false
    var appResults: [AppInfo] = [] {
        didSet { categoryViewModel.apps = appResults }
    }
    var errorMessage: String?
    var warningMessage: String?
    var navigationTitle: String
    var folderURL: URL? {
        didSet {
            if persistsFolder {
                UserDefaults.standard.set(folderURL?.path, forKey: Self.folderPathKey)
            }
        }
    }

    let categoryViewModel = CategoryViewModel()

    @ObservationIgnored private let persistsFolder: Bool
    @ObservationIgnored private let detectService = DetectService()
    @ObservationIgnored private let scanService = ScanService()
    @ObservationIgnored private let diskCacheService = DiskCacheService()
    @ObservationIgnored private var appCache: [String: CachedApp]

    /// - Parameter startupFolderURL: A folder from the command line; used for this launch only.
    init(startupFolderURL: URL? = nil) {
        persistsFolder = startupFolderURL == nil
        let folderURL = startupFolderURL ?? Self.savedFolderURL()
        self.folderURL = folderURL
        navigationTitle = folderURL?.lastPathComponent ?? Constants.AppName
        appCache = diskCacheService.load()
    }

    private static func savedFolderURL() -> URL? {
        let defaults = UserDefaults.standard
        if let path = defaults.string(forKey: folderPathKey) {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        // Earlier versions saved a security-scoped bookmark; the app isn't sandboxed, so a path suffices.
        guard let bookmark = defaults.data(forKey: legacyBookmarkKey) else { return nil }
        defaults.removeObject(forKey: legacyBookmarkKey)
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        defaults.set(url.path, forKey: folderPathKey)
        return url
    }

    func reset(title: String = "Select Folder", errorMessage: String? = nil) {
        appResults = []
        self.errorMessage = errorMessage
        warningMessage = nil
        navigationTitle = title
    }

    func clearCachesAndRescan() {
        diskCacheService.clear()
        appCache.removeAll()
        Task {
            await scanApplications()
        }
    }

    func selectNewFolderAndScan() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Folder"

        guard openPanel.runModal() == .OK, let url = openPanel.url else { return }
        folderURL = url
        Task {
            await scanApplications()
        }
    }

    func scanApplications() async {
        guard let folderURL else {
            reset(title: "No Folder", errorMessage: "No folder selected.")
            return
        }
        guard !isLoading else { return }

        reset(title: "Scanning…")
        categoryViewModel.resetFilters()
        isLoading = true
        defer { isLoading = false }

        let scanResult: ScanService.ScanResult
        do {
            scanResult = try scanService.scanWithDiagnostics(folderURL: folderURL)
        } catch {
            reset(title: "Scan Error", errorMessage: error.localizedDescription)
            return
        }

        let permissionNote = "Some folders could not be scanned due to permissions."
        guard !scanResult.appURLs.isEmpty else {
            let message = "No applications found in the selected folder."
            reset(title: "No Apps Found", errorMessage: scanResult.hasSkippedDirectories ? "\(message) \(permissionNote)" : message)
            return
        }
        if scanResult.hasSkippedDirectories {
            warningMessage = permissionNote
        }

        await analyzeApps(at: scanResult.appURLs)
        diskCacheService.save(appCache)
        navigationTitle = folderURL.lastPathComponent
    }

    private func analyzeApps(at urls: [URL]) async {
        let detectService = detectService
        let requests = urls.map { (url: $0, cached: appCache[$0.path]) }
        var apps: [AppInfo] = []
        apps.reserveCapacity(urls.count)

        await forEachConcurrently(requests) { request in
            (request.url, AppAnalyzer.analyze(request.url, cached: request.cached, detectService: detectService))
        } receive: { url, analysis in
            appCache[url.path] = analysis
            apps.append(AppInfo(url: url, analysis: analysis))
            if apps.count % Self.publishBatchSize == 0 || apps.count == urls.count {
                appResults = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                navigationTitle = "Scanning (\(apps.count * 100 / urls.count)%)…"
            }
        }
    }

    private func forEachConcurrently<Input: Sendable, Output: Sendable>(
        _ inputs: [Input],
        transform: @escaping @Sendable (Input) async -> Output,
        receive: (Output) -> Void
    ) async {
        await withTaskGroup(of: Output.self) { group in
            var pending = inputs.makeIterator()
            for _ in 0..<Self.concurrencyLimit {
                guard let input = pending.next() else { break }
                group.addTask { await transform(input) }
            }
            for await output in group {
                receive(output)
                if let input = pending.next() {
                    group.addTask { await transform(input) }
                }
            }
        }
    }
}
