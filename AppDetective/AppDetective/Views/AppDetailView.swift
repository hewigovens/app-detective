import AppKit
import DetectiveCore
import SwiftUI

struct AppDetailView: View {
    let app: AppInfo?

    var body: some View {
        if let app {
            details(for: app)
        } else {
            ContentUnavailableView("No Selection", systemImage: "app.dashed", description: Text("Select an app to see its details."))
        }
    }

    private func details(for app: AppInfo) -> some View {
        VStack(spacing: 0) {
            header(for: app)
            Form {
                Section {
                    LabeledContent("Version", value: app.version ?? "—")
                    LabeledContent("Bundle ID", value: app.bundleId ?? "—")
                    LabeledContent("Category", value: app.category.description)
                    LabeledContent("Size", value: app.size ?? "—")
                    LabeledContent("Path") {
                        Text(app.path)
                            .font(.callout.monospaced())
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }
                }
                Section("Tech Stacks") {
                    StackTagRow(techStacks: app.techStacks, possibleStacks: app.possibleStacks)
                }
                Section("Evidence") {
                    EvidenceGrid(appInfo: app)
                }
            }
            .formStyle(.grouped)
        }
        .textSelection(.enabled)
    }

    private func header(for app: AppInfo) -> some View {
        HStack(spacing: 12) {
            AppIcon(iconData: app.iconData)
                .frame(width: 56, height: 56)
            Text(app.name)
                .font(.title2.weight(.semibold))
                .lineLimit(2)
            Spacer()
            Menu {
                Button("Show in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
                }
                Button("Copy as JSON", systemImage: "doc.on.doc") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(String(decoding: ResultsExporter.json([app]), as: UTF8.self), forType: .string)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding()
    }
}

#Preview {
    AppDetailView(app: AppInfo.samples[0])
        .frame(width: 320, height: 600)
}
