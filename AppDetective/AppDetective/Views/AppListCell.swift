import AppKit
import DetectiveCore
import SwiftUI

struct AppListCell: View {
    let appInfo: AppInfo
    @State private var isShowingEvidence = false

    var body: some View {
        HStack(spacing: 12) {
            icon
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
                HStack(spacing: 4) {
                    ForEach(TechStack.allStacks.filter(appInfo.techStacks.contains), id: \.self) { stack in
                        StackTag(stack: stack)
                    }
                    ForEach(TechStack.allStacks.filter(appInfo.possibleStacks.contains), id: \.self) { stack in
                        StackTag(stack: stack, isPossible: true)
                    }
                }
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
                .foregroundStyle(.tertiary)
        }
    }
}

private struct StackTag: View {
    let stack: TechStack
    var isPossible = false

    var body: some View {
        Text(isPossible ? "\(stack.displayName)?" : stack.displayName)
            .font(.caption.weight(.medium))
            .foregroundStyle(isPossible ? AnyShapeStyle(.secondary) : AnyShapeStyle(stack.mainColor))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(stack.mainColor.opacity(isPossible ? 0 : 0.14), in: Capsule())
            .overlay {
                if isPossible {
                    Capsule().strokeBorder(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
            }
    }
}

private struct EvidenceView: View {
    let appInfo: AppInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appInfo.name)
                .font(.headline)

            if appInfo.evidence.isEmpty {
                Text("No specific evidence found; native apps fall back to AppKit.")
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 6) {
                    ForEach(appInfo.evidence, id: \.self) { evidence in
                        GridRow {
                            Text(evidence.isStrong ? "Strong" : "Weak")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(evidence.isStrong ? .green : .orange)
                            Text(evidence.stack)
                                .fontWeight(.medium)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(evidence.rule)
                                Text(evidence.item)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }

            if !appInfo.possibleStacks.isEmpty {
                Text("Stacks marked “?” have only weak evidence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 440, alignment: .leading)
    }
}

#Preview {
    List(AppInfo.samples) { app in
        AppListCell(appInfo: app)
    }
    .frame(width: 500)
}
