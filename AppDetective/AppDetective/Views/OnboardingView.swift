import AppKit
import SwiftUI

struct OnboardingView: View {
    @State private var selectedFolderBookmark: Data? = nil
    @State private var selectedFolderName: String? = nil
    var onPermissionGranted: (Data) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.accentColor)

            Text("Welcome to \(Constants.AppName)!")
                .font(.largeTitle)

            Text("To get started, \(Constants.AppName) needs permission to scan a folder containing your applications. This allows the app to analyze the tech stack used by each application.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("By default, we suggest scanning the main /Applications folder, but you can choose any folder.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Select Applications Folder") {
                selectFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let folderName = selectedFolderName {
                Text("Selected: \(folderName)")
                    .font(.caption)
                    .foregroundColor(.green)
            }
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
