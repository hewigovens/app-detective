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

    // Category ViewModel
    let categoryViewModel: CategoryViewModel

    private var iconCache: [String: Data] = [:]
    private var sizeCache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: Constants.BundleId + ".cacheQueue")
    private let metadataLoader: MetadataLoaderService
    private let scanService: ScanService
    private let detectService: DetectService
    private var loadedMetadataCount: Int = 0
    private let diskCacheService: DiskCacheService

    // Initialization for live app usage
    init() {
        self.diskCacheService = DiskCacheService()
        self.metadataLoader = MetadataLoaderService()
        self.detectService = DetectService()
        self.scanService = ScanService()
        self.categoryViewModel = CategoryViewModel()
        loadExistingCaches()
        setupMetadataLoaderCallbacks()
        print("[ViewModel] ContentViewModel initialized for live app.")
    }

    // Initialization for previews or testing with a specific folder
    init(folderURL: URL?, categoryViewModel: CategoryViewModel) {
        self.folderURL = folderURL
        self.diskCacheService = DiskCacheService()
        self.metadataLoader = MetadataLoaderService()
        self.detectService = DetectService()
        self.scanService = ScanService()
        self.categoryViewModel = categoryViewModel
        loadExistingCaches()
        setupMetadataLoaderCallbacks()
        print("[ViewModel] ContentViewModel initialized for preview/test. Folder: \(folderURL?.path ?? "Not set")")
    }

    private func loadExistingCaches() {
        print("[ViewModel] Attempting to load existing caches from disk...")
        iconCache = diskCacheService.loadIconCache() ?? [:]
        sizeCache = diskCacheService.loadSizeCache() ?? [:]
        print("[ViewModel] Loaded \(iconCache.count) icons and \(sizeCache.count) sizes from disk cache.")
    }

    // Keep existing init for previews or direct instantiation if needed
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
        print("[ViewModel] Attempting to load caches from disk...")
        if let loadedIcons = diskCacheService.loadIconCache() {
            iconCache = loadedIcons
        }
        if let loadedSizes = diskCacheService.loadSizeCache() {
            sizeCache = loadedSizes
        }
    }

    // Setup callbacks for MetadataLoaderService
    private func setupMetadataLoaderCallbacks() {
        metadataLoader.onMetadataItemLoaded = { [weak self] path, iconData, sizeString in
            // This closure will be called on the main thread by MetadataLoaderService
            guard let self = self else { return }
            Task {
                // Ensure cacheData is called within a Task if it's async and to keep it on MainActor
                await self.cacheData(path: path, iconData: iconData, sizeString: sizeString)
            }
        }

        metadataLoader.onAllMetadataLoaded = { [weak self] in
            // This closure will be called on the main thread by MetadataLoaderService
            guard let self = self else { return }
            self.metadataLoadingDidComplete() // This is already @MainActor
        }
    }

    // MARK: - Scanning and Loading Logic

    // Add function to clear caches and trigger a full rescan
    func clearCachesAndRescan() {
        print("[ViewModel] Clearing caches and initiating rescan...")
        // Clear disk caches
        diskCacheService.clearAllCaches()

        // Clear in-memory state
        iconCache.removeAll()
        sizeCache.removeAll() // Clear size cache as well
        appResults.removeAll() // Clear previous scan results
        errorMessage = nil
        scanProgress = 0.0
        metadataLoadProgress = 0.0
        totalMetadataItems = 0
        loadedMetadataCount = 0
        navigationTitle = Constants.AppName

        // Ensure isLoading is false before starting scan
        isLoading = false

        // Trigger the scan if a folder is selected
        if folderURL != nil {
            Task {
                await scanApplications()
            }
        } else {
            navigationTitle = "Select Folder" // Or appropriate initial state
            print("[ViewModel] No folder selected, cannot rescan.")
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
                // Stop accessing the old security-scoped resource, if any
                folderURL?.stopAccessingSecurityScopedResource()

                folderURL = newURL // Update to the new folder URL

                print("[ViewModel] New folder selected: \(newURL.path). Initiating rescan.")
                // Call clearCachesAndRescan, which will use the new folderURL
                clearCachesAndRescan()
            } else {
                print("[ViewModel] No folder was selected from the panel.")
            }
        } else {
            print("[ViewModel] Folder selection panel was cancelled.")
        }
    }

    func scanApplications() async {
        // Ensure we have a valid URL before scanning
        guard let currentFolderURL = folderURL else {
            print("Scan attempted without a valid folder URL.")
            errorMessage = "No folder selected."
            navigationTitle = "No Folder"
            appResults = []
            isLoading = false
            return
        }

        // Reset state and update title for scanning start
        appResults = [] // Clear previous results
        errorMessage = nil
        isLoading = true // Mark scanning as started
        scanProgress = 0.0
        totalAppsToScan = 0 // Reset count
        navigationTitle = "Scanning..." // Simple scanning title

        var detectedApps: [AppInfo] = []

        do {
            // Start accessing the security-scoped resource
            guard currentFolderURL.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected folder. Please reselect."
                isLoading = false
                // Also reset progress on early exit
                scanProgress = 0.0
                totalAppsToScan = 0
                navigationTitle = "Error Accessing Folder" // Update title
                return
            }

            defer { currentFolderURL.stopAccessingSecurityScopedResource() }

            // Get initial count for progress calculation
            let allAppURLs = try scanService.scan(folderURL: currentFolderURL)
            totalAppsToScan = allAppURLs.count
            guard totalAppsToScan > 0 else {
                print("No .app bundles found in the directory.")
                errorMessage = "No applications found in the selected folder."
                isLoading = false
                navigationTitle = "No Apps Found" // Update title immediately
                return // Exit if no apps found
            }

            // Use TaskGroup for concurrent detection
            await withTaskGroup(of: AppInfo?.self) { group in
                for url in allAppURLs {
                    group.addTask { [weak self] in
                        guard let self = self else { return nil }
                        let appName = url.deletingPathExtension().lastPathComponent
                        let detectedStack = await self.detectService.detectStack(for: url)
                        let category = await self.detectService.extractCategory(from: url)
                        let appInfo = AppInfo(name: appName, path: url.path, techStacks: detectedStack, category: category)
                        return appInfo
                    }
                }

                for await result in group {
                    // Only update progress counter here
                    if totalAppsToScan > 0 {
                        // Calculate progress based on appended apps
                        let currentProgress = Double(detectedApps.count + 1) / Double(totalAppsToScan)
                        self.scanProgress = min(currentProgress, 1.0)
                    }

                    if let appInfo = result {
                        detectedApps.append(appInfo)
                    }
                }
            }

            // Sort results alphabetically by name before updating state
            detectedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            appResults = detectedApps // Assign results *before* setting final state

            // Update the category ViewModel with our app results
            categoryViewModel.updateCategories(with: appResults)

        } catch let error as ScanService.ScanError {
            errorMessage = error.localizedDescription
            navigationTitle = "Scan Error" // Set error title
            isLoading = false // Stop loading on error
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            navigationTitle = "Unexpected Error" // Set error title
            isLoading = false // Stop loading on error
        }

        // --- Final State Update Logic Moved ---
        // If an error occurred during scan, isLoading is already false.
        // If scan succeeded, decide whether to continue loading or finish.
        if errorMessage == nil {
            if appResults.isEmpty {
                // No apps found, finish now.
                isLoading = false
                navigationTitle = "No Apps Found"
                scanProgress = 1.0
                print("Finished scanning. No apps found.")
            } else {
                // Apps found, start metadata loading phase.
                // Initialize metadata tracking state
                totalMetadataItems = appResults.count
                loadedMetadataCount = 0
                metadataLoadProgress = 0.0
                // Set initial title for metadata phase
                navigationTitle = "Loading Details (0%)..."
                // Keep isLoading = true
                scanProgress = 1.0 // Scan part is done.
                print("Finished scan phase. Starting metadata load for \(appResults.count) apps.")
                // --- Start background loading after scan ---
                let pathsToLoad = appResults.map { $0.path } // Use appResults now
                var pathsRequiringMetadataLoad: [String] = []
                var initiallyCachedCount = 0

                for path in pathsToLoad {
                    if let iconData = iconCache[path], let size = sizeCache[path] {
                        // If data is in cache, apply it to the AppInfo model directly
                        if let index = appResults.firstIndex(where: { $0.path == path }) {
                            appResults[index].iconData = iconData
                            appResults[index].size = size
                            // Consider adding an `isMetadataLoaded` flag to AppInfo if more granular control is needed
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
                    metadataLoadProgress = 1.0 // Or 0.0, if no apps, should be 1.0 as it's 'done'
                }

                print("[ViewModel] From \(appResults.count) apps: \(initiallyCachedCount) had full metadata cached, \(pathsRequiringMetadataLoad.count) require loading.")

                if pathsRequiringMetadataLoad.isEmpty {
                    print("[ViewModel] All metadata already cached. Completing metadata phase immediately.")
                    // No need to call isLoading = true here, it's already true from the start of startInitialLoadOrRescan
                    metadataLoadingDidComplete() // This will set isLoading to false
                } else {
                    print("[ViewModel] Enqueuing \(pathsRequiringMetadataLoad.count) paths for metadata loading.")
                    metadataLoader.enqueuePaths(pathsRequiringMetadataLoad)
                }
            }
        }
        // If errorMessage is not nil, isLoading and title are set in catch blocks.
        // Removed final print here, moved to completion points.
    }

    // Called by MetadataLoaderService when all items are processed
    @MainActor
    func metadataLoadingDidComplete() {
        print("[ViewModel] Attempting to complete metadata loading. Current isLoading: \(isLoading)")
        // Ensure we only update state if we were actually loading metadata
        if isLoading { // Check isLoading to prevent accidental state change if scan errored earlier
            isLoading = false
            metadataLoadProgress = 1.0 // Ensure metadata progress hits 100%
            // Final title should reflect the results loaded during the scan phase
            if appResults.isEmpty { // Should ideally not happen if metadata was loaded, but check anyway
                navigationTitle = "No Apps Found"
            } else {
                navigationTitle = folderURL?.lastPathComponent ?? Constants.AppName
            }
            // Ensure progress is visually complete
            scanProgress = 1.0
            print("[ViewModel] Finished all phases. Final count: \(appResults.count) apps. Title: \(navigationTitle)")

            // Update the category ViewModel with our finalized app results
            categoryViewModel.updateCategories(with: appResults)

            // Save caches to disk ONCE after all items are processed
            print("[ViewModel] Saving final icon and size caches to disk...")
            diskCacheService.saveIconCache(iconCache)
            diskCacheService.saveSizeCache(sizeCache)

        } else {
            print("[ViewModel] metadataLoadingDidComplete called but isLoading was already false. State not changed.")
        }
    }

    // MARK: - Caching Methods

    func getIconData(for path: String) -> Data? {
        cacheQueue.sync { iconCache[path] }
    }

    func getSizeString(for path: String) -> String? {
        cacheQueue.sync { sizeCache[path] }
    }

    @MainActor // Ensure this runs on the main actor as it touches UI-relevant state
    func cacheData(path: String, iconData: Data?, sizeString: String?) async {
        // Notify SwiftUI that this object is about to change
        objectWillChange.send()

        // Check if data was already cached to avoid double counting progress
        let wasAlreadyCached = (iconCache[path] != nil && sizeCache[path] != nil)

        // Update caches (no need for cacheQueue if always called on main actor)
        if let data = iconData {
            iconCache[path] = data
        }
        if let size = sizeString {
            sizeCache[path] = size
        }

        // Update progress only if this is a new item being fully cached
        if !wasAlreadyCached && iconCache[path] != nil && sizeCache[path] != nil && totalMetadataItems > 0 {
            loadedMetadataCount += 1
            metadataLoadProgress = Double(loadedMetadataCount) / Double(totalMetadataItems)
            // Update navigation title with percentage
            let percentage = Int(metadataLoadProgress * 100)
            navigationTitle = "Loading Details (\(percentage)%...)"
        } else if totalMetadataItems == 0 {
            print("[ViewModel] Warning: cacheData called but totalMetadataItems is 0.")
        }
    }
}
