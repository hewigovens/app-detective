import DetectiveCore
import SwiftUI

struct TraitTag: View {
    let trait: Trait
    var isPossible = false

    var body: some View {
        Text(isPossible ? "\(trait.name)?" : trait.name)
            .font(.caption.weight(.medium))
            .foregroundStyle(isPossible ? Color(nsColor: .secondaryLabelColor) : trait.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(trait.color.opacity(isPossible ? 0 : 0.14), in: Capsule())
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
            ForEach(Trait.sorted(traits)) { trait in
                TraitTag(trait: trait)
            }
            ForEach(Trait.sorted(possibleTraits)) { trait in
                TraitTag(trait: trait, isPossible: true)
            }
        }
    }
}
