import DetectiveCore
import SwiftUI

struct StackTag: View {
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

struct StackTagRow: View {
    let techStacks: TechStack
    let possibleStacks: TechStack

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TechStack.allStacks.filter(techStacks.contains), id: \.self) { stack in
                StackTag(stack: stack)
            }
            ForEach(TechStack.allStacks.filter(possibleStacks.contains), id: \.self) { stack in
                StackTag(stack: stack, isPossible: true)
            }
        }
    }
}
