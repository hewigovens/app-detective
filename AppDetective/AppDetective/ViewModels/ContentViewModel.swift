import DetectiveCore
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class ContentViewModel {
    private static let concurrencyLimit = 8
    private static let publishBatchSize = 8

    private static let folderPathsKey = "scanFolderPaths"
    private static let legacyFolderPathKey = "scanFolderPath"
    private static let legacyBookmarkKey = "selectedFolderBookmark"

    private(set) var progress: Double?
    var appResults: [AppInfo] = [] {
        didSet { categoryViewModel.apps = appResults }
    }
    var errorMessage: String?
    var warningMessage: String?
    var isShowingInspector = false
    var folderURLs: [URL] {
        didSet {
            if persistsFolders {
                UserDefaults.standard.set(folderURLs.map(\.path), forKey: Self.folderPathsKey)
            }
        }
    }

    let categoryViewModel = CategoryViewModel()

    @ObservationIgnored private let persistsFolders: Bool
    @ObservationIgnored private let detectService = DetectService()
    @ObservationIgnored private let scanService = ScanService()
    @ObservationIgnored private let diskCacheService = DiskCacheService()
    @ObservationIgnored private var appCache: [String: CachedApp]

    var isLoading: Bool {
        progress != nil
    }

    var title: String {
        switch folderURLs.count {
        case 0: Constants.AppName
        case 1: folderURLs[0].lastPathComponent
        default: "\(folderURLs.count) Folders"
        }
    }

    // A folder passed on the command line is used for this launch only.
    init(startupFolderURL: URL? = nil) {
        persistsFolders = startupFolderURL == nil
        folderURLs = startupFolderURL.map { [$0] } ?? Self.savedFolderURLs()
        appCache = diskCacheService.load()
    }

    private static func savedFolderURLs() -> [URL] {
        let defaults = UserDefaults.standard
        if let paths = defaults.stringArray(forKey: folderPathsKey) {
            return paths.map { URL(fileURLWithPath: $0, isDirectory: true) }
        }

        var legacyURL = defaults.string(forKey: legacyFolderPathKey).map { URL(fileURLWithPath: $0, isDirectory: true) }
        // Earlier versions saved a security-scoped bookmark; the app isn't sandboxed, so a path suffices.
        if legacyURL == nil, let bookmark = defaults.data(forKey: legacyBookmarkKey) {
            var isStale = false
            legacyURL = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &isStale)
        }
        defaults.removeObject(forKey: legacyFolderPathKey)
        defaults.removeObject(forKey: legacyBookmarkKey)

        let urls = legacyURL.map { [$0] } ?? []
        defaults.set(urls.map(\.path), forKey: folderPathsKey)
        return urls
    }

    func addFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"

        guard panel.runModal() == .OK else { return }
        let newURLs = panel.urls.filter { url in !folderURLs.contains { $0.standardizedFileURL == url.standardizedFileURL } }
        guard !newURLs.isEmpty else { return }
        folderURLs += newURLs
        rescan()
    }

    func removeFolder(_ url: URL) {
        folderURLs.removeAll { $0 == url }
        if folderURLs.isEmpty {
            appResults = []
        } else {
            rescan()
        }
    }

    func clearCachesAndRescan() {
        diskCacheService.clear()
        appCache.removeAll()
        rescan()
    }

    private func rescan() {
        Task {
            await scanApplications()
        }
    }

    func scanApplications() async {
        guard !folderURLs.isEmpty, !isLoading else { return }

        appResults = []
        errorMessage = nil
        warningMessage = nil
        categoryViewModel.resetFilters()
        progress = 0
        defer { progress = nil }

        var appURLs: [URL] = []
        var seenPaths: Set<String> = []
        var failures: [String] = []
        var hasSkippedDirectories = false
        for folderURL in folderURLs {
            do {
                let result = try scanService.scanWithDiagnostics(folderURL: folderURL)
                appURLs += result.appURLs.filter { seenPaths.insert($0.standardizedFileURL.path).inserted }
                hasSkippedDirectories = hasSkippedDirectories || result.hasSkippedDirectories
            } catch {
                failures.append(error.localizedDescription)
            }
        }

        var warnings = failures
        if hasSkippedDirectories {
            warnings.append("Some folders could not be scanned due to permissions.")
        }
        guard !appURLs.isEmpty else {
            errorMessage = (["No applications found."] + warnings).joined(separator: " ")
            return
        }
        warningMessage = warnings.isEmpty ? nil : warnings.joined(separator: " ")

        await analyzeApps(at: appURLs)
        diskCacheService.save(appCache)
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
            progress = Double(apps.count) / Double(urls.count)
            if apps.count % Self.publishBatchSize == 0 || apps.count == urls.count {
                appResults = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

    func exportResults() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText, .json]
        panel.nameFieldStringValue = "\(title).csv"
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let apps = categoryViewModel.filteredApps
        let data = url.pathExtension.lowercased() == "json" ? ResultsExporter.json(apps) : ResultsExporter.csv(apps)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            warningMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}
