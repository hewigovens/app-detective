import AppKit
import SwiftUI

struct OnboardingView: View {
    @State private var selectedFolderBookmark: Data? = nil
    @State private var selectedFolderName: String? = nil
    var onPermissionGranted: (Data) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)

            Text("Welcome to \(Constants.AppName)")
                .font(.largeTitle)

            Text("Pick a folder to scan for apps.")
                .foregroundColor(.secondary)

            Button("Choose Folder") {
                selectFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let folderName = selectedFolderName {
                Text("Selected: \(folderName)")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Spacer().frame(height: 4)

            Text("Tip: install the `appdetective` CLI from the **\(Constants.AppName)** menu to inspect a single app from your terminal.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.message = "Please select the folder containing your applications."
        panel.prompt = "Select Folder"
        panel.allowedContentTypes = [.folder]
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        if panel.runModal() == .OK {
            if let url = panel.url {
                do {
                    let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    selectedFolderBookmark = bookmarkData
                    selectedFolderName = url.lastPathComponent
                    onPermissionGranted(bookmarkData)
                } catch {
                    print("Error creating bookmark data: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView { _ in }
    }
}
