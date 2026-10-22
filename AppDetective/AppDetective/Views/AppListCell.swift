import DetectiveCore
import SwiftUI

struct AppListCell: View {
    // How the app is built; graphics, distribution, security, and background items are in the detail view.
    private static let listedKinds: Set<TraitKind> = [.ui, .language, .renderer, .updater]

    let appInfo: AppInfo
    @State private var isShowingEvidence = false

    var body: some View {
        HStack(spacing: 12) {
            AppIcon(iconData: appInfo.iconData)
                .frame(width: 36, height: 36)

            // Explicit colors: a focused selection would otherwise turn the text white on the row's light tint.
            VStack(alignment: .leading, spacing: 2) {
                Text(appInfo.name)
                    .font(.headline)
                    .foregroundStyle(Color(nsColor: .labelColor))
                    .lineLimit(1)
                Text([appInfo.category.description, appInfo.size].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                isShowingEvidence = true
            } label: {
                TraitTagRow(traits: appInfo.traits.of(Self.listedKinds), possibleTraits: appInfo.possibleTraits.of(Self.listedKinds))
            }
            .buttonStyle(.plain)
            .help("Show detection evidence")
            .popover(isPresented: $isShowingEvidence, arrowEdge: .trailing) {
                EvidenceView(appInfo: appInfo)
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
