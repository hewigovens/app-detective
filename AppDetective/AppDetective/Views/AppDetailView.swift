import AppKit
import DetectiveCore
import SwiftUI

struct AppDetailView: View {
    let app: AppInfo?

    var body: some View {
        if let app {
            details(for: app)
        } else {
            ContentUnavailableView("No Selection", systemImage: "app.dashed", description: Text("Double-click an app to see its details."))
        }
    }

    private func details(for app: AppInfo) -> some View {
        VStack(spacing: 0) {
            header(for: app)
            Form {
                Section {
                    LabeledContent("Version", value: app.version ?? "—")
                    LabeledContent("Category", value: app.category.description)
                    LabeledContent("Size", value: app.size ?? "—")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Path")
                        Text(app.path)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                Section("Tech Stacks") {
                    StackTagRow(techStacks: app.techStacks, possibleStacks: app.possibleStacks)
                }
                Section("Evidence") {
                    EvidenceList(appInfo: app)
                }
            }
            .formStyle(.grouped)
        }
        .textSelection(.enabled)
    }

    private func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func header(for app: AppInfo) -> some View {
        HStack(spacing: 12) {
            AppIcon(iconData: app.iconData)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .help(app.name)
                Text(app.bundleId ?? "No bundle identifier")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(app.bundleId ?? "")
            }
            Spacer(minLength: 8)
            Menu {
                Button("Show in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
                }
                Button("Copy Path", systemImage: "doc.on.clipboard") {
                    copy(app.path)
                }
                Button("Copy as JSON", systemImage: "doc.on.doc") {
                    copy(String(decoding: ResultsExporter.json([app]), as: UTF8.self))
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
