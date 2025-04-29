import SwiftUI
import AppKit

struct OnboardingView: View {
    // State variable to store the bookmark data
    @State private var selectedFolderBookmark: Data? = nil
    // Store the last selected folder name for display
    @State private var selectedFolderName: String? = nil
    // Callback closure to notify when permission is granted (passes bookmark data)
    var onPermissionGranted: (Data) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.accentColor)

            Text("Welcome to App Detective!")
                .font(.largeTitle)

            Text("To get started, App Detective needs permission to scan a folder containing your applications. This allows the app to analyze the tech stack used by each application.")
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

    // Function to open NSOpenPanel
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.message = "Please select the folder containing your applications."
        panel.prompt = "Select Folder"
        panel.allowedContentTypes = [.folder] // Allow only folders
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        // Set the initial directory (best effort)
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        if panel.runModal() == .OK {
            if let url = panel.url {
                print("Selected folder URL: \(url.path)")
                do {
                    // Create security-scoped bookmark data
                    let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    print("Bookmark data created.")
                    selectedFolderBookmark = bookmarkData
                    selectedFolderName = url.lastPathComponent
                    // Call the callback with the bookmark data
                    onPermissionGranted(bookmarkData)
                } catch {
                    // Handle error creating bookmark
                    print("Error creating bookmark data: \(error.localizedDescription)")
                    // Optionally show an error to the user
                }
            } else {
                print("No folder URL received from panel.")
            }
        } else {
            print("User cancelled the panel.")
        }
    }
}

// Preview provider for OnboardingView
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a dummy action for the preview
        OnboardingView { bookmarkData in
            print("Preview: Permission granted with bookmark data (length: \(bookmarkData.count))")
        }
    }
}
