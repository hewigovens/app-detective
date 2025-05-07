//
//  AppDetectiveApp.swift
//  AppDetective
//
//  Created by hewig on 4/29/25.
//

import SwiftUI

@main
struct AppDetectiveApp: App {
    // Use AppStorage to persist the selected folder's bookmark data
    @AppStorage("selectedFolderBookmark") private var selectedFolderBookmark: Data?
    // Use @StateObject for the ViewModel lifecycle
    @StateObject private var contentViewModel = ContentViewModel()
    @State private var isResolvingBookmark: Bool = true // New state for loading

    var body: some Scene {
        WindowGroup {
            Group { // Outer group for loading state
                if isResolvingBookmark {
                    Spacer()
                } else {
                    // Existing logic to choose between ContentView and OnboardingView
                    Group {
                        if contentViewModel.folderURL != nil {
                            // Display ContentView, viewModel is guaranteed to exist
                            ContentView(viewModel: contentViewModel)
                                .task { // Re-add task modifier to trigger scan when ContentView appears
                                    print("[AppDetectiveApp] ContentView appeared, triggering scan via .task...")
                                    await contentViewModel.scanApplications()
                                }
                        } else {
                            // Show onboarding if no URL is set in the ViewModel yet
                            OnboardingView { bookmarkData in
                                // Save the bookmark data
                                selectedFolderBookmark = bookmarkData
                                print("Bookmark data saved.")
                                // Attempt to resolve the URL immediately, which updates the ViewModel
                                // We also need to ensure isResolvingBookmark becomes false if user selects a folder here
                                // but resolveBookmark() already handles setting isResolvingBookmark = false.
                                resolveBookmark()
                            }
                        }
                    }
                }
            }
            // Modifiers moved to the outer Group to ensure they are active
            .onAppear {
                // Attempt to resolve the bookmark when the view appears
                // This will update the viewModel's folderURL if successful
                print("[AppDetectiveApp] onAppear, attempting to resolve bookmark...")
                resolveBookmark()
            }
            .onChange(of: selectedFolderBookmark) { _, _ in // Using new syntax for Swift 5.5+
                print("[AppDetectiveApp] selectedFolderBookmark changed, resolving...")
                resolveBookmark()
            }
            .onChange(of: contentViewModel.folderURL) { _, newURL in // Using new syntax
                if let urlToSave = newURL {
                    do {
                        let newBookmarkData = try urlToSave.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        if newBookmarkData != selectedFolderBookmark {
                            print("[AppDetectiveApp] contentViewModel.folderURL changed to \(urlToSave.path). Saving new bookmark.")
                            selectedFolderBookmark = newBookmarkData
                        }
                    } catch {
                        print("[AppDetectiveApp] Error creating bookmark data from contentViewModel.folderURL: \(error.localizedDescription)")
                    }
                } else {
                    if selectedFolderBookmark != nil {
                        print("[AppDetectiveApp] contentViewModel.folderURL is nil. Clearing persisted bookmark.")
                        selectedFolderBookmark = nil
                    }
                }
            }
        }
    }

    // Function to resolve the bookmark data into a URL and update the ViewModel
    private func resolveBookmark() {
        guard let bookmarkData = selectedFolderBookmark else {
            print("No bookmark data found. Clearing ViewModel URL.")
            // Ensure the view model's URL is nil if no bookmark exists
            if contentViewModel.folderURL != nil {
                contentViewModel.folderURL = nil
                // Optionally clear other VM state if needed when folder is lost
                contentViewModel.appResults = []
                contentViewModel.errorMessage = nil
                contentViewModel.navigationTitle = "Select Folder"
            }
            isResolvingBookmark = false // Update loading state
            return
        }

        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

            if isStale {
                print("Bookmark is stale, attempting to refresh...")
                // If stale, create a new bookmark data and save it
                let freshBookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                selectedFolderBookmark = freshBookmarkData
                print("Refreshed and saved new bookmark data.")
            }

            // Successfully resolved URL - update the ViewModel's URL
            // Check if it's different before assigning to prevent unnecessary updates/scans
            if contentViewModel.folderURL != url {
                print("Bookmark resolved successfully: \(url.path). Updating ViewModel URL.")
                contentViewModel.folderURL = url
                // Scan is now triggered by .task on ContentView when it appears due to this change
            } else {
                print("Bookmark resolved successfully, but URL hasn't changed.")
            }

        } catch {
            print("Error resolving bookmark: \(error.localizedDescription)")
            // Clear the invalid/stale bookmark data if resolution fails
            selectedFolderBookmark = nil
            // Clear the ViewModel's URL
            contentViewModel.folderURL = nil
            contentViewModel.errorMessage = "Error resolving bookmark."
            contentViewModel.navigationTitle = "Error"
        }
        isResolvingBookmark = false // Update loading state
    }
}
