import AppKit
import SwiftUI

struct OnboardingView: View {
    var onFoldersSelected: ([URL]) -> Void

    private var applicationFolders: [URL] {
        let userApplications = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        return [URL(fileURLWithPath: "/Applications", isDirectory: true), userApplications]
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)

            Text("Welcome to \(Constants.AppName)")
                .font(.largeTitle)

            Text("Find out what each of your apps is built with.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Scan Applications") {
                    onFoldersSelected(applicationFolders)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

                Button("Choose Folders…") {
                    selectFolders()
                }
            }
            .controlSize(.large)

            Text("Tip: install the `appdetective` CLI from the **\(Constants.AppName)** menu to inspect a single app from your terminal.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 4)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    private func selectFolders() {
        let panel = NSOpenPanel()
        panel.message = "Choose the folders containing your applications."
        panel.prompt = "Scan"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        onFoldersSelected(panel.urls)
    }
}

#Preview {
    OnboardingView { _ in }
}
