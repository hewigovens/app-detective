import DetectiveCore
import SwiftUI

struct TraitTag: View {
    let trait: Trait
    var isPossible = false

    // A colored dot on a neutral capsule, like the sidebar: rows of fully tinted tags were loud, and
    // neighboring warm colors such as Swift and Rust blurred together.
    var body: some View {
        HStack(spacing: 4) {
            if !isPossible {
                Circle()
                    .fill(trait.color)
                    .frame(width: 6, height: 6)
            }
            Text(isPossible ? "\(trait.name)?" : trait.name)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Color(nsColor: isPossible ? .tertiaryLabelColor : .secondaryLabelColor))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(isPossible ? 0 : 0.5), in: Capsule())
        .overlay {
            if isPossible {
                Capsule().strokeBorder(Color(nsColor: .secondaryLabelColor).opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            }
        }
    }
}

struct TraitTagRow: View {
    let traits: Set<Trait>
    let possibleTraits: Set<Trait>

    var body: some View {
        HStack(spacing: 4) {
            ForEach(traits.sorted()) { trait in
                TraitTag(trait: trait)
            }
            ForEach(possibleTraits.sorted()) { trait in
                TraitTag(trait: trait, isPossible: true)
            }
        }
    }
}
