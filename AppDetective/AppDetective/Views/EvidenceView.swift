import SwiftUI

// The popover shown from a row's stack tags.
struct EvidenceView: View {
    let appInfo: AppInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appInfo.name)
                .font(.headline)
            EvidenceGrid(appInfo: appInfo)
        }
        .padding()
        .frame(width: 440, alignment: .leading)
    }
}

struct EvidenceGrid: View {
    let appInfo: AppInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
    }
}
