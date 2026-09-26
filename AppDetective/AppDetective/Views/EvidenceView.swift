import SwiftUI

// The popover shown from a row's stack tags.
struct EvidenceView: View {
    let appInfo: AppInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appInfo.name)
                .font(.headline)
            EvidenceList(appInfo: appInfo)
        }
        .padding()
        .frame(width: 440, alignment: .leading)
    }
}

struct EvidenceList: View {
    let appInfo: AppInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appInfo.evidence.isEmpty {
                Text("No specific evidence found; native apps fall back to AppKit.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appInfo.evidence, id: \.self) { evidence in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(evidence.stack)
                                .fontWeight(.medium)
                            Text(evidence.isStrong ? "Strong" : "Weak")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(evidence.isStrong ? .green : .orange)
                        }
                        Text(evidence.kind ?? evidence.rule)
                            .foregroundStyle(.secondary)
                        Text(evidence.item)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .help(evidence.rule)
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
