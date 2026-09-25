import AppKit
import DetectiveCore
import SwiftUI

struct AppListCell: View {
    let appInfo: AppInfo

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(appInfo.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Group {
                    Text(appInfo.category.description)
                    Text(appInfo.size ?? "Loading size…")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }

            Spacer()

            if !appInfo.techStacks.isEmpty {
                Text(appInfo.techStacks.displayNames.joined(separator: ", "))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(appInfo.techStacks.mainColor)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(appInfo.techStacks.mainColor.opacity(0.15))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: appInfo.path)])
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let data = appInfo.iconData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .scaledToFit()
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    List(AppInfo.samples) { app in
        AppListCell(appInfo: app)
    }
    .frame(width: 400)
}
