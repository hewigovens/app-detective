import DetectiveCore
import Foundation
import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var scanProgress: Double = 0.0
    @Published var totalAppsToScan: Int = 0
    @Published var appResults: [AppInfo] = []
    @Published var errorMessage: String? = nil
    @Published var navigationTitle: String = Constants.AppName
    @Published var folderURL: URL? = nil
    @Published var metadataLoadProgress: Double = 0.0
    @Published var totalMetadataItems: Int = 0

    let categoryViewModel: CategoryViewModel

    private var iconCache: [String: Data] = [:]
    private var sizeCache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: Constants.BundleId + ".cacheQueue")
    private let metadataLoader: MetadataLoaderService
    private let scanService: ScanService
    private let detectService: DetectService
    private var loadedMetadataCount: Int = 0
    private let diskCacheService: DiskCacheService

    init() {
        self.diskCacheService = DiskCacheService()
        self.metadataLoader = MetadataLoaderService()
        self.detectService = DetectService()
        self.scanService = ScanService()
        self.categoryViewModel = CategoryViewModel()
        loadExistingCaches()
        setupMetadataLoaderCallbacks()
    }

    init(folderURL: URL?, categoryViewModel: CategoryViewModel) {
        self.folderURL = folderURL
        self.diskCacheService = DiskCacheService()
        self.metadataLoader = MetadataLoaderService()
        self.detectService = DetectService()
        self.scanService = ScanService()
        self.categoryViewModel = categoryViewModel
        loadExistingCaches()
        setupMetadataLoaderCallbacks()
    }

    private func loadExistingCaches() {
        iconCache = diskCacheService.loadIconCache() ?? [:]
        sizeCache = diskCacheService.loadSizeCache() ?? [:]
    }

    init(folderURL: URL?) {
        self.folderURL = folderURL
        self.navigationTitle = folderURL?.lastPathComponent ?? Constants.AppName
        self.diskCacheService = DiskCacheService()
        self.metadataLoader = MetadataLoaderService()
        self.detectService = DetectService()
        self.scanService = ScanService()
        self.categoryViewModel = CategoryViewModel()
        setupMetadataLoaderCallbacks()
        loadCachesFromDisk()
    }

    // MARK: - Cache Loading/Saving

    private func loadCachesFromDisk() {
        if let loadedIcons = diskCacheService.loadIconCache() {
            iconCache = loadedIcons
        }
        if let loadedSizes = diskCacheService.loadSizeCache() {
            sizeCache = loadedSizes
        }
    }

    private func setupMetadataLoaderCallbacks() {
        metadataLoader.onMetadataItemLoaded = { [weak self] path, iconData, sizeString in
            guard let self = self else { return }
            Task {
                await self.cacheData(path: path, iconData: iconData, sizeString: sizeString)
            }
        }

        metadataLoader.onAllMetadataLoaded = { [weak self] in
            guard let self = self else { return }
            self.metadataLoadingDidComplete()
        }
    }

    // MARK: - Scanning and Loading Logic

    func clearCachesAndRescan() {
        diskCacheService.clearAllCaches()
        iconCache.removeAll()
        sizeCache.removeAll()
        appResults.removeAll()
        errorMessage = nil
        scanProgress = 0.0
        metadataLoadProgress = 0.0
        totalMetadataItems = 0
        loadedMetadataCount = 0
        navigationTitle = Constants.AppName
        isLoading = false

        if folderURL != nil {
            Task {
                await scanApplications()
            }
        } else {
            navigationTitle = "Select Folder"
        }
    }

    func selectNewFolderAndScan() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Folder"

        if openPanel.runModal() == .OK {
            if let newURL = openPanel.url {
                folderURL?.stopAccessingSecurityScopedResource()
                folderURL = newURL
                clearCachesAndRescan()
            }
        }
    }

    func scanApplications() async {
        guard let currentFolderURL = folderURL else {
            errorMessage = "No folder selected."
            navigationTitle = "No Folder"
            appResults = []
            isLoading = false
            return
        }

        appResults = []
        errorMessage = nil
        isLoading = true
        scanProgress = 0.0
        totalAppsToScan = 0
        navigationTitle = "Scanning..."

        var detectedApps: [AppInfo] = []

        do {
            guard currentFolderURL.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected folder. Please reselect."
                isLoading = false
                scanProgress = 0.0
                totalAppsToScan = 0
                navigationTitle = "Error Accessing Folder"
                return
            }

            defer { currentFolderURL.stopAccessingSecurityScopedResource() }

            let allAppURLs = try scanService.scan(folderURL: currentFolderURL)
            totalAppsToScan = allAppURLs.count
            guard totalAppsToScan > 0 else {
                errorMessage = "No applications found in the selected folder."
                isLoading = false
                navigationTitle = "No Apps Found"
                return
            }

            await withTaskGroup(of: AppInfo?.self) { group in
                for url in allAppURLs {
                    group.addTask { [weak self] in
                        guard let self = self else { return nil }
                        let appName = url.deletingPathExtension().lastPathComponent
                        let detectedStack = await self.detectService.detectStack(for: url)
                        let category = await self.detectService.extractCategory(from: url)
                        let bundleId = Bundle(url: url)?.bundleIdentifier
                        let appInfo = AppInfo(name: appName, path: url.path, bundleId: bundleId, techStacks: detectedStack, category: category)
                        return appInfo
                    }
                }

                for await result in group {
                    if totalAppsToScan > 0 {
                        let currentProgress = Double(detectedApps.count + 1) / Double(totalAppsToScan)
                        self.scanProgress = min(currentProgress, 1.0)
                    }

                    if let appInfo = result {
                        detectedApps.append(appInfo)
                    }
                }
            }

            detectedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            // Assign results before setting final state
            appResults = detectedApps
            categoryViewModel.updateCategories(with: appResults)

        } catch let error as ScanService.ScanError {
            errorMessage = error.localizedDescription
            navigationTitle = "Scan Error"
            isLoading = false
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            navigationTitle = "Unexpected Error"
            isLoading = false
        }

        if errorMessage == nil {
            if appResults.isEmpty {
                isLoading = false
                navigationTitle = "No Apps Found"
                scanProgress = 1.0
            } else {
                totalMetadataItems = appResults.count
                loadedMetadataCount = 0
                metadataLoadProgress = 0.0
                navigationTitle = "Loading Details (0%)..."
                scanProgress = 1.0

                let pathsToLoad = appResults.map { $0.path }
                var pathsRequiringMetadataLoad: [String] = []
                var initiallyCachedCount = 0

                for path in pathsToLoad {
                    if let iconData = iconCache[path], let size = sizeCache[path] {
                        if let index = appResults.firstIndex(where: { $0.path == path }) {
                            appResults[index].iconData = iconData
                            appResults[index].size = size
                        }
                        initiallyCachedCount += 1
                    } else {
                        pathsRequiringMetadataLoad.append(path)
                    }
                }

                loadedMetadataCount = initiallyCachedCount
                totalMetadataItems = appResults.count

                if totalMetadataItems > 0 {
                    metadataLoadProgress = Double(loadedMetadataCount) / Double(totalMetadataItems)
                } else {
                    metadataLoadProgress = 1.0
                }

                if pathsRequiringMetadataLoad.isEmpty {
                    metadataLoadingDidComplete()
                } else {
                    metadataLoader.enqueuePaths(pathsRequiringMetadataLoad)
                }
            }
        }
    }

    @MainActor
    func metadataLoadingDidComplete() {
        if isLoading {
            isLoading = false
            metadataLoadProgress = 1.0
            if appResults.isEmpty {
                navigationTitle = "No Apps Found"
            } else {
                navigationTitle = folderURL?.lastPathComponent ?? Constants.AppName
            }
            scanProgress = 1.0

            categoryViewModel.updateCategories(with: appResults)

            // Save caches once after all items are processed
            diskCacheService.saveIconCache(iconCache)
            diskCacheService.saveSizeCache(sizeCache)
        }
    }

    // MARK: - Caching Methods

    func getIconData(for path: String) -> Data? {
        cacheQueue.sync { iconCache[path] }
    }

    func getSizeString(for path: String) -> String? {
        cacheQueue.sync { sizeCache[path] }
    }

    @MainActor
    func cacheData(path: String, iconData: Data?, sizeString: String?) async {
        objectWillChange.send()

        let wasAlreadyCached = (iconCache[path] != nil && sizeCache[path] != nil)

        if let data = iconData {
            iconCache[path] = data
        }
        if let size = sizeString {
            sizeCache[path] = size
        }

        if !wasAlreadyCached && iconCache[path] != nil && sizeCache[path] != nil && totalMetadataItems > 0 {
            loadedMetadataCount += 1
            metadataLoadProgress = Double(loadedMetadataCount) / Double(totalMetadataItems)
            let percentage = Int(metadataLoadProgress * 100)
            navigationTitle = "Loading Details (\(percentage)%...)"
        }
    }
}
