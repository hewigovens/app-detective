import AppKit
import DetectiveCore
import SwiftUI

struct AppListCell: View {
    let appInfo: AppInfo
    @State private var isShowingEvidence = false

    var body: some View {
        HStack(spacing: 12) {
            AppIcon(iconData: appInfo.iconData)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(appInfo.name)
                    .font(.headline)
                    .lineLimit(1)
                Text([appInfo.category.description, appInfo.size].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                isShowingEvidence = true
            } label: {
                StackTagRow(techStacks: appInfo.techStacks, possibleStacks: appInfo.possibleStacks)
            }
            .buttonStyle(.plain)
            .help("Show detection evidence")
            .popover(isPresented: $isShowingEvidence, arrowEdge: .trailing) {
                EvidenceView(appInfo: appInfo)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Show in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: appInfo.path)])
            }
        }
    }
}

#Preview {
    List(AppInfo.samples) { app in
        AppListCell(appInfo: app)
    }
    .frame(width: 500)
}
