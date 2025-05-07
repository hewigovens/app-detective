import Foundation
import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var scanProgress: Double = 0.0
    @Published var totalAppsToScan: Int = 0
    @Published var appResults: [AppInfo] = []
    @Published var errorMessage: String? = nil
    @Published var navigationTitle: String = "App Detective"
    @Published var folderURL: URL? = nil
    @Published var metadataLoadProgress: Double = 0.0
    @Published var totalMetadataItems: Int = 0

    // Category ViewModel
    let categoryViewModel = CategoryViewModel()

    private var iconCache: [String: Data] = [:]
    private var sizeCache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: "hi.hewig.app.detective.cacheQueue") // For thread-safe access
    private let metadataLoader = MetadataLoaderService()
    private let scanService = ScanService()
    private let detectService = DetectService()
    private var loadedMetadataCount: Int = 0
    private let diskCacheService = DiskCacheService() // Add instance of disk cache service

    // Keep existing init for previews or direct instantiation if needed
    init(folderURL: URL?) {
        self.folderURL = folderURL
        self.navigationTitle = folderURL?.lastPathComponent ?? "App Detective"
        metadataLoader.setViewModel(self) // Ensure loader has reference
        loadCachesFromDisk() // Load caches when initialized
    }

    // Add a default initializer
    init() {
        self.folderURL = nil
        self.navigationTitle = "App Detective"
        metadataLoader.setViewModel(self) // Ensure loader has reference
        loadCachesFromDisk() // Load caches when initialized
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

    // MARK: - Scanning and Loading Logic

    // Add function to clear caches and trigger a full rescan
    func clearCachesAndRescan() {
        print("[ViewModel] Clearing caches and initiating rescan...")
        // Clear disk caches
        diskCacheService.clearAllCaches()

        // Clear in-memory state
        iconCache.removeAll()
        sizeCache.removeAll()
        appResults.removeAll() // Clear previous scan results
        errorMessage = nil
        scanProgress = 0.0
        metadataLoadProgress = 0.0
        totalMetadataItems = 0
        loadedMetadataCount = 0
        navigationTitle = "App Detective" // Reset title

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
                metadataLoader.enqueuePaths(pathsToLoad)
                // -------------------------------------------
            }
        }
        // If errorMessage is not nil, isLoading and title are set in catch blocks.
        // Removed final print here, moved to completion points.
    }

    // Called by MetadataLoaderService when all items are processed
    @MainActor
    func metadataLoadingDidComplete() {
        print("[ViewModel] Metadata loading complete.")
        // Ensure we only update state if we were actually loading metadata
        if isLoading { // Check isLoading to prevent accidental state change if scan errored earlier
            isLoading = false
            metadataLoadProgress = 1.0 // Ensure metadata progress hits 100%
            // Final title should reflect the results loaded during the scan phase
            if appResults.isEmpty { // Should ideally not happen if metadata was loaded, but check anyway
                navigationTitle = "No Apps Found"
            } else {
                navigationTitle = "App Detective"
            }
            // Ensure progress is visually complete
            scanProgress = 1.0
            print("Finished all phases. Final count: \(appResults.count) apps. Title: \(navigationTitle)")

            // Update the category ViewModel with our finalized app results
            categoryViewModel.updateCategories(with: appResults)
        } else {
            print("[ViewModel] metadataLoadingDidComplete called but isLoading was already false.")
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
            // Save updated icon cache to disk
            diskCacheService.saveIconCache(iconCache)
        }
        if let size = sizeString {
            sizeCache[path] = size
            // Save updated size cache to disk
            diskCacheService.saveSizeCache(sizeCache)
        }

        // Update progress only if this is a new item being fully cached
        if !wasAlreadyCached && iconCache[path] != nil && sizeCache[path] != nil && totalMetadataItems > 0 {
            loadedMetadataCount += 1
            metadataLoadProgress = Double(loadedMetadataCount) / Double(totalMetadataItems)
            // Update navigation title with percentage
            let percentage = Int(metadataLoadProgress * 100)
            navigationTitle = "Loading Details (\(percentage)%...)"
            print("[ViewModel] Metadata Progress: \(percentage)% (\(loadedMetadataCount)/\(totalMetadataItems))")
        } else if totalMetadataItems == 0 {
            print("[ViewModel] Warning: cacheData called but totalMetadataItems is 0.")
        }
    }
}
