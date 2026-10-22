import SwiftUI

// The popover shown from a row's trait tags.
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
            ForEach(appInfo.evidence, id: \.self) { evidence in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(evidence.trait)
                            .fontWeight(.medium)
                        Text(evidence.isStrong ? "Strong" : "Weak")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(evidence.isStrong ? .green : .orange)
                    }
                    Text(evidence.label)
                        .foregroundStyle(.secondary)
                    Text(evidence.item)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                .fixedSize(horizontal: false, vertical: true)
                .help(evidence.rule)
            }

            let inferred = appInfo.inferredTraits
            if !inferred.isEmpty {
                Text("\(inferred.names.formatted(.list(type: .and))): inferred, as nothing more specific was found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !appInfo.possibleTraits.isEmpty {
                Text("Traits marked “?” have only weak evidence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
