import SwiftUI

@main
struct AppDetectiveApp: App {
    @AppStorage("selectedFolderBookmark") private var selectedFolderBookmark: Data?
    @StateObject private var contentViewModel = ContentViewModel()
    @State private var isResolvingBookmark: Bool = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isResolvingBookmark {
                    Spacer()
                } else {
                    Group {
                        if contentViewModel.folderURL != nil {
                            ContentView(viewModel: contentViewModel)
                                .task {
                                    print("[AppDetectiveApp] ContentView appeared, triggering scan via .task...")
                                    await contentViewModel.scanApplications()
                                }
                        } else {
                            OnboardingView { bookmarkData in
                                selectedFolderBookmark = bookmarkData
                                print("Bookmark data saved.")
                                resolveBookmark()
                                // We also need to ensure isResolvingBookmark becomes false if user selects a folder here
                                // but resolveBookmark() already handles setting isResolvingBookmark = false.
                                resolveBookmark()
                            }
                        }
                    }
                }
            }
            .onAppear {
                print("[AppDetectiveApp] onAppear, attempting to resolve bookmark...")
                resolveBookmark()
            }
            .onChange(of: selectedFolderBookmark) { _, _ in
                print("[AppDetectiveApp] selectedFolderBookmark changed, resolving...")
                resolveBookmark()
            }
            .onChange(of: contentViewModel.folderURL) { _, newURL in
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
            isResolvingBookmark = false
            return
        }

        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

            if isStale {
                print("Bookmark is stale, attempting to refresh...")
                let freshBookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                selectedFolderBookmark = freshBookmarkData
                print("Refreshed and saved new bookmark data.")
            }

            if contentViewModel.folderURL != url {
                print("Bookmark resolved successfully: \(url.path). Updating ViewModel URL.")
                contentViewModel.folderURL = url
            } else {
                print("Bookmark resolved successfully, but URL hasn't changed.")
            }

        } catch {
            print("Error resolving bookmark: \(error.localizedDescription)")
            selectedFolderBookmark = nil
            contentViewModel.folderURL = nil
            contentViewModel.errorMessage = "Error resolving bookmark."
            contentViewModel.navigationTitle = "Error"
        }
        isResolvingBookmark = false
    }
}
