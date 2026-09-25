import Foundation
import SwiftUI

@main
struct AppDetectiveApp: App {
    @State private var contentViewModel = ContentViewModel(startupFolderURL: LaunchArguments.startupFolderURL)
    @State private var updater = SparkleUpdater()

    var body: some Scene {
        WindowGroup {
            if contentViewModel.folderURL != nil {
                ContentView(viewModel: contentViewModel)
                    .task {
                        await contentViewModel.scanApplications()
                    }
            } else {
                OnboardingView { url in
                    contentViewModel.folderURL = url
                }
            }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button {
                    AppActions.showAboutWindow(updater: updater)
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
                        await AppActions.installCLI()
                    }
                } label: {
                    Label("Install Command Line Tool…", systemImage: "terminal")
                }
                .disabled(CLIInstallerService.bundledBinaryURL() == nil)
            }
            // A single window shares one scan; hide File > New Window.
            CommandGroup(replacing: .newItem) {}
        }
    }
}
