import AppKit
import SwiftUI

struct AppListCell: View {
    let appInfo: AppInfo
    @EnvironmentObject var viewModel: ContentViewModel // Inject the ViewModel

    var body: some View {
        // Get data directly from ViewModel cache within the body calculation
        let cachedIconData = viewModel.getIconData(for: appInfo.path)
        // Replace the unused variable with _ to avoid the warning
        let _ = viewModel.getSizeString(for: appInfo.path)

        HStack(spacing: 12) {
            // Display icon if loaded from cache, else placeholder
            Group {
                // Cached data IS the thumbnail data now
                if let thumbnailData = cachedIconData, let thumbnailImage = NSImage(data: thumbnailData) {
                    Image(nsImage: thumbnailImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "app.dashed") // Placeholder icon
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40, height: 40) // Consistent frame

            VStack(alignment: .leading, spacing: 2) {
                Text(appInfo.name)
                    .font(.headline)
                    .lineLimit(1)
                // Display joined tech stack names
                Text(appInfo.techStacks.displayNames.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(appInfo.techStacks.mainColor) // Use prioritized color
                    .lineLimit(1) // Prevent wrapping if too many stacks
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(appInfo.techStacks.mainColor.opacity(0.15)) // Subtle background using the color
                    .cornerRadius(4)

                // Display category
                Text(appInfo.category.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Display size if loaded from cache, else placeholder
                Text(viewModel.getSizeString(for: appInfo.path) ?? "Loading size...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer() // Pushes content to the left
        }
        .padding(.vertical, 4)
    }
}

struct AppListCell_Previews: PreviewProvider {
    static var previews: some View {
        List {
            AppListCell(
                appInfo: AppInfo(
                    name: "ExampleApp very long name to test truncation.app",
                    path: "/Applications/Calculator.app",
                    techStacks: .electron,
                    category: .utilities
                )
            ) // Use a real app path for preview icon/size
            AppListCell(
                appInfo: AppInfo(
                    name: "Another App.app",
                    path: "/Applications/Safari.app",
                    techStacks: .appKit,
                    category: .reference
                )
            )
            AppListCell(
                appInfo: AppInfo(
                    name: "MyPythonThing.app",
                    path: "/System/Applications/Messages.app",
                    techStacks: .python,
                    category: .socialNetworking
                )
            )
            AppListCell(
                appInfo: AppInfo(
                    name: "UnknownApp.app",
                    path: "/System/Applications/Mail.app",
                    techStacks: [],
                    category: .productivity
                )
            )
        }
        .frame(width: 350) // Increase preview width slightly
        .environmentObject(ContentViewModel()) // Provide the environment object for preview
    }
}
