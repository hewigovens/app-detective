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

    // Centralized Caches
    private var iconCache: [String: Data] = [:]
    private var sizeCache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: "hi.hewig.app.detective.cacheQueue") // For thread-safe access

    // Background loading service
    private let metadataLoader = MetadataLoaderService()
    private let scanService = ScanService()
    private let detectService = DetectService()

    // Keep existing init for previews or direct instantiation if needed
    init(folderURL: URL?) {
        self.folderURL = folderURL
        self.navigationTitle = folderURL?.lastPathComponent ?? "App Detective"
        metadataLoader.setViewModel(self) // Ensure loader has reference
    }

    // Add a default initializer
    init() {
        self.folderURL = nil
        self.navigationTitle = "App Detective"
        metadataLoader.setViewModel(self) // Ensure loader has reference
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
                for appURL in allAppURLs {
                    group.addTask { [weak self] in
                        guard let self = self else { return nil }
                        let appName = appURL.deletingPathExtension().lastPathComponent
                        let stack = await self.detectService.detectStack(for: appURL)
                        return AppInfo(name: appName, path: appURL.path, techStack: stack.rawValue)
                    }
                }

                for await result in group {
                    // Only update progress counter here
                    if totalAppsToScan > 0 {
                         // Calculate progress based on appended apps
                         let currentProgress = Double(detectedApps.count + 1) / Double(totalAppsToScan)
                         self.scanProgress = min(currentProgress, 1.0) // Update scanProgress directly
                         // DO NOT update navigationTitle percentage here
                    }

                    if let appInfo = result {
                        detectedApps.append(appInfo)
                    }
                }
            }

            // Sort results alphabetically by name before updating state
            detectedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            appResults = detectedApps // Assign results *before* setting final state

        } catch let error as ScanService.ScanError {
            errorMessage = error.localizedDescription
            navigationTitle = "Scan Error" // Set error title
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            navigationTitle = "Unexpected Error" // Set error title
        }

        // --- Final State Update ---
        isLoading = false // Set loading to false *after* processing

        // Set final navigation title based on outcome (only if no error occurred)
        if errorMessage == nil {
             scanProgress = 1.0 // Ensure progress hits 100% on success
             if appResults.isEmpty {
                 navigationTitle = "No Apps Found"
             } else {
                 navigationTitle = "Detected Apps (\(appResults.count))"
             }
        } 
        // If errorMessage is not nil, the title was already set in catch blocks

        print("Finished scanning. Final count: \(appResults.count) apps. Title: \(navigationTitle)")
        // --------------------------

        // --- Start background loading after scan ---
        // Ensure we use the final sorted list
        let pathsToLoad = detectedApps.map { $0.path }
        metadataLoader.enqueuePaths(pathsToLoad)
        // -------------------------------------------
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

        // Update caches (no need for cacheQueue if always called on main actor)
        if let data = iconData {
            iconCache[path] = data
        }
        if let size = sizeString {
            sizeCache[path] = size
        }
    }
}
