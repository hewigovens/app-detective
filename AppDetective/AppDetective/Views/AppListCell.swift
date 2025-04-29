import AppKit
import SwiftUI

struct AppListCell: View {
    let appInfo: AppInfo
    @EnvironmentObject var viewModel: ContentViewModel // Inject the ViewModel

    var body: some View {
        // Get data directly from ViewModel cache within the body calculation
        let cachedIconData = viewModel.getIconData(for: appInfo.path)
        let cachedSizeString = viewModel.getSizeString(for: appInfo.path)

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

            VStack(alignment: .leading) {
                Text(appInfo.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(appInfo.techStack)
                    .font(.caption)
                    .padding(.horizontal, 8) // Add horizontal padding
                    .padding(.vertical, 4) // Add vertical padding
                    .background(Color.blue.opacity(0.2)) // Add a background color
                    .foregroundColor(.blue) // Set text color
                    .cornerRadius(8) // Round the corners

                // Display size if loaded from cache, else placeholder
                if let size = cachedSizeString {
                    Text(size)
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("Calculating size...") // Placeholder text
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer() // Pushes content to the left
        }
        .padding(.vertical, 4)
        .background(Color.white)
    }
}

struct AppListCell_Previews: PreviewProvider {
    static var previews: some View {
        List {
            AppListCell(appInfo: AppInfo(name: "ExampleApp very long name to test truncation.app", path: "/Applications/Calculator.app", techStack: "Electron")) // Use a real app path for preview icon/size
            AppListCell(appInfo: AppInfo(name: "Another App.app", path: "/Applications/Safari.app", techStack: "SwiftUI"))
            AppListCell(appInfo: AppInfo(name: "MyPythonThing.app", path: "/System/Applications/Messages.app", techStack: "Python"))
            AppListCell(appInfo: AppInfo(name: "UnknownApp.app", path: "/System/Applications/Mail.app", techStack: "Unknown"))
        }
        .frame(width: 350) // Increase preview width slightly
    }
}
