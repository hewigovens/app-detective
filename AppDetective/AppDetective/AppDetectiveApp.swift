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
                                    await contentViewModel.scanApplications()
                                }
                        } else {
                            OnboardingView { bookmarkData in
                                selectedFolderBookmark = bookmarkData
                                resolveBookmark()
                                resolveBookmark()
                            }
                        }
                    }
                }
            }
            .onAppear {
                resolveBookmark()
            }
            .onChange(of: selectedFolderBookmark) { _, _ in
                resolveBookmark()
            }
            .onChange(of: contentViewModel.folderURL) { _, newURL in
                if let urlToSave = newURL {
                    do {
                        let newBookmarkData = try urlToSave.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        if newBookmarkData != selectedFolderBookmark {
                            selectedFolderBookmark = newBookmarkData
                        }
                    } catch {
                        print("Error creating bookmark data: \(error.localizedDescription)")
                    }
                } else {
                    if selectedFolderBookmark != nil {
                        selectedFolderBookmark = nil
                    }
                }
            }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button {
                    AppDetectiveApp.showAboutWindow()
                } label: {
                    Label("About App Detective", systemImage: "info.circle")
                }
            }
            CommandGroup(replacing: .newItem) {
                Button {
                } label: {
                    Label("New Window", systemImage: "plus.rectangle")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    private static var aboutWindowController: NSWindowController?

    static func showAboutWindow() {
        if aboutWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 350, height: 300),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            window.center()
            window.title = "About"
            window.contentView = NSHostingView(rootView: AboutView())
            aboutWindowController = NSWindowController(window: window)
        }

        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func resolveBookmark() {
        guard let bookmarkData = selectedFolderBookmark else {
            if contentViewModel.folderURL != nil {
                contentViewModel.folderURL = nil
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
                let freshBookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                selectedFolderBookmark = freshBookmarkData
            }

            if contentViewModel.folderURL != url {
                contentViewModel.folderURL = url
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
