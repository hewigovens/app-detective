import Foundation
import SwiftUI

@main
struct AppDetectiveApp: App {
    @AppStorage("selectedFolderBookmark") private var selectedFolderBookmark: Data?
    @StateObject private var contentViewModel: ContentViewModel
    @StateObject private var updater = SparkleUpdater()
    @State private var isResolvingBookmark: Bool
    private let startupFolderURL: URL?

    init() {
        let startupFolderURL = LaunchArguments.startupFolderURL
        self.startupFolderURL = startupFolderURL
        _contentViewModel = StateObject(wrappedValue: ContentViewModel(folderURL: startupFolderURL))
        _isResolvingBookmark = State(initialValue: startupFolderURL == nil)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isResolvingBookmark {
                    ProgressView()
                        .frame(minWidth: 500, minHeight: 400)
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
                guard startupFolderURL == nil else { return }
                resolveBookmark()
            }
            .onChange(of: selectedFolderBookmark) { _, _ in
                guard startupFolderURL == nil else { return }
                resolveBookmark()
            }
            .onChange(of: contentViewModel.folderURL) { _, newURL in
                guard startupFolderURL == nil else { return }
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
                    AppDetectiveApp.showAboutWindow(updater: updater)
                } label: {
                    Label("About App Detective", systemImage: "info.circle")
                }
                Button {
                    updater.checkForUpdates()
                } label: {
                    Label("Check for Updates…", systemImage: "arrow.down.circle")
                }
                .disabled(!updater.canCheckForUpdates)
                Divider()
                Button {
                    Task {
                        await AppDetectiveApp.installCLI()
                    }
                } label: {
                    Label("Install Command Line Tool…", systemImage: "terminal")
                }
                .disabled(CLIInstallerService.bundledBinaryURL() == nil)
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

    @MainActor
    static func installCLI() async {
        let isOnPath = await CLIInstallerService.isOnPath()
        let alert = NSAlert()
        let wasInstalled = CLIInstallerService.isInstalled()
        if wasInstalled {
            alert.messageText = "Command Line Tool Already Installed"
            alert.informativeText = if isOnPath {
                "`appdetective` is already available at \(CLIInstallerService.installPath). Reinstall to update the symlink, or remove it."
            } else {
                "`appdetective` is linked at \(CLIInstallerService.installPath), but the directory is not in your PATH.\n\n\(CLIInstallerService.pathHint)"
            }
            alert.addButton(withTitle: "Reinstall")
            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Cancel")
        } else {
            alert.messageText = "Install Command Line Tool"
            alert.informativeText = "This will create a symlink at \(CLIInstallerService.installPath) so you can run `appdetective <path-to-.app>` from your terminal."
            alert.addButton(withTitle: "Install")
            alert.addButton(withTitle: "Cancel")
        }

        switch (wasInstalled, alert.runModal()) {
        case (true, .alertFirstButtonReturn), (false, .alertFirstButtonReturn):
            performInstall(isOnPath: isOnPath)
        case (true, .alertSecondButtonReturn):
            performUninstall()
        default:
            return
        }
    }

    @MainActor
    private static func performInstall(isOnPath: Bool) {
        do {
            try CLIInstallerService.install()
            let alert = NSAlert()
            alert.messageText = "Command Line Tool Installed"
            var message = "`appdetective` is linked at \(CLIInstallerService.installPath)."
            if !isOnPath {
                message += "\n\nThe directory is not in your PATH.\n\n\(CLIInstallerService.pathHint)"
            }
            alert.informativeText = message
            alert.runModal()
        } catch {
            showErrorAlert(title: "Installation Failed", message: error.localizedDescription)
        }
    }

    @MainActor
    private static func performUninstall() {
        do {
            try CLIInstallerService.uninstall()
            let alert = NSAlert()
            alert.messageText = "Command Line Tool Removed"
            alert.informativeText = "Removed \(CLIInstallerService.installPath)."
            alert.runModal()
        } catch {
            showErrorAlert(title: "Removal Failed", message: error.localizedDescription)
        }
    }

    @MainActor
    private static func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private static var aboutWindowController: NSWindowController?

    static func showAboutWindow(updater: SparkleUpdater) {
        if aboutWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 350, height: 300),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            window.center()
            window.title = "About"
            window.contentView = NSHostingView(rootView: AboutView(updater: updater))
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
                contentViewModel.warningMessage = nil
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
            contentViewModel.warningMessage = nil
            contentViewModel.navigationTitle = "Error"
        }
        isResolvingBookmark = false
    }
}
