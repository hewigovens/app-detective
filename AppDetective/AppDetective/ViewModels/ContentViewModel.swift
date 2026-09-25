import DetectiveCore
import Foundation
import SwiftUI

@MainActor
final class ContentViewModel: ObservableObject {
    /// Upper bound on concurrent per-app work, which blocks on `otool`/`strings` and disk I/O.
    private static let concurrencyLimit = 8
    /// Number of loaded icons to accumulate before publishing, so the list isn't redrawn per icon.
    private static let publishBatchSize = 8

    @Published var isLoading = false
    @Published var appResults: [AppInfo] = [] {
        didSet { categoryViewModel.apps = appResults }
    }
    @Published var errorMessage: String?
    @Published var warningMessage: String?
    @Published var navigationTitle: String
    @Published var folderURL: URL?

    let categoryViewModel = CategoryViewModel()

    private let detectService = DetectService()
    private let scanService = ScanService()
    private let diskCacheService = DiskCacheService()
    private var metadataCache: [String: CachedMetadata]

    init(folderURL: URL? = nil) {
        self.folderURL = folderURL
        self.navigationTitle = folderURL?.lastPathComponent ?? Constants.AppName
        self.metadataCache = diskCacheService.load()
    }

    // MARK: - Actions

    /// Clears results and messages, e.g. when the saved folder is forgotten.
    func reset(title: String = "Select Folder", errorMessage: String? = nil) {
        appResults = []
        self.errorMessage = errorMessage
        warningMessage = nil
        navigationTitle = title
    }

    func clearCachesAndRescan() {
        diskCacheService.clear()
        metadataCache.removeAll()
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

    // MARK: - Scanning

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

        let isSecurityScoped = folderURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

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

        appResults = await detectApps(at: scanResult.appURLs)
        await loadMetadata()
        diskCacheService.save(metadataCache)
        navigationTitle = folderURL.lastPathComponent
    }

    private func detectApps(at urls: [URL]) async -> [AppInfo] {
        let detectService = detectService
        var apps: [AppInfo] = []
        apps.reserveCapacity(urls.count)

        await forEachConcurrently(urls) { url in
            await AppInfo(
                name: url.deletingPathExtension().lastPathComponent,
                path: url.path,
                bundleId: Bundle(url: url)?.bundleIdentifier,
                techStacks: detectService.detectStack(for: url),
                category: detectService.extractCategory(from: url)
            )
        } receive: { app in
            apps.append(app)
            navigationTitle = "Scanning (\(apps.count * 100 / urls.count)%)…"
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadMetadata() async {
        var results = appResults
        let requests = results.indices.map { (index: $0, path: results[$0].path, cached: metadataCache[results[$0].path]) }
        var completed = 0

        await forEachConcurrently(requests) { request in
            (request.index, MetadataLoaderService.metadata(forAppAt: request.path, cached: request.cached))
        } receive: { index, metadata in
            results[index].iconData = metadata.iconData
            results[index].size = metadata.size
            metadataCache[results[index].path] = metadata
            completed += 1

            if completed % Self.publishBatchSize == 0 || completed == requests.count {
                appResults = results
                navigationTitle = "Loading Details (\(completed * 100 / requests.count)%)…"
            }
        }
    }

    /// Runs `transform` over `inputs` with bounded concurrency, handing each result to `receive`
    /// on the main actor as soon as it's ready.
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
