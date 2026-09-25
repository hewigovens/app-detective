import DetectiveCore
import LSAppCategory
import SwiftUI

struct CategoryView: View {
    @ObservedObject var viewModel: CategoryViewModel

    var body: some View {
        List {
            Section("Categories") {
                FilterRow(
                    title: "All Apps",
                    count: viewModel.apps.count,
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    categoryIcon("square.grid.2x2")
                } action: {
                    viewModel.selectedCategory = nil
                }

                ForEach(viewModel.sortedCategories) { category in
                    FilterRow(
                        title: category.description,
                        count: viewModel.categoryCounts[category] ?? 0,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        categoryIcon(category.sfSymbol)
                    } action: {
                        viewModel.selectedCategory = category
                    }
                }
            }

            Section("Tech Stacks") {
                FilterRow(title: "All", count: nil, isSelected: viewModel.selectedTechStack == nil) {
                    EmptyView()
                } action: {
                    viewModel.selectedTechStack = nil
                }

                ForEach(TechStack.allStacks, id: \.self) { stack in
                    if let count = viewModel.stackCounts[stack], count > 0 {
                        FilterRow(
                            title: stack.displayName,
                            count: count,
                            isSelected: viewModel.selectedTechStack == stack
                        ) {
                            Circle()
                                .fill(stack.mainColor)
                                .frame(width: 12, height: 12)
                        } action: {
                            viewModel.selectedTechStack = stack
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedCategory)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedTechStack)
    }

    private func categoryIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 12))
            .frame(width: 16)
    }
}

private struct FilterRow<Icon: View>: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon()
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.2)))
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}

#Preview {
    let viewModel = CategoryViewModel()
    viewModel.apps = AppInfo.samples
    return CategoryView(viewModel: viewModel)
        .frame(width: 220, height: 500)
}
