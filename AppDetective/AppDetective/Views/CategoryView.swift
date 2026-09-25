import DetectiveCore
import LSAppCategory
import SwiftUI

struct CategoryView: View {
    @ObservedObject var viewModel: CategoryViewModel

    var body: some View {
        List(selection: selection) {
            Section("Categories") {
                Label("All Apps", systemImage: "square.grid.2x2")
                    .badge(viewModel.apps.count)
                    .tag(SidebarItem.allCategories)

                ForEach(viewModel.sortedCategories) { category in
                    Label(category.description, systemImage: category.sfSymbol)
                        .badge(viewModel.categoryCounts[category] ?? 0)
                        .tag(SidebarItem.category(category))
                }
            }

            Section("Tech Stacks") {
                Label("All Stacks", systemImage: "square.stack.3d.up")
                    .tag(SidebarItem.allStacks)

                ForEach(TechStack.allStacks, id: \.self) { stack in
                    if let count = viewModel.stackCounts[stack], count > 0 {
                        Label {
                            Text(stack.displayName)
                        } icon: {
                            Circle()
                                .fill(stack.mainColor)
                                .frame(width: 9, height: 9)
                        }
                        .badge(count)
                        .tag(SidebarItem.stack(stack))
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    // Category and stack filters combine, so each section keeps its own selected row.
    private var selection: Binding<Set<SidebarItem>> {
        Binding {
            selectedItems
        } set: { items in
            for item in items.subtracting(selectedItems) {
                switch item {
                case .allCategories: viewModel.selectedCategory = nil
                case let .category(category): viewModel.selectedCategory = category
                case .allStacks: viewModel.selectedTechStack = nil
                case let .stack(stack): viewModel.selectedTechStack = stack
                }
            }
        }
    }

    private var selectedItems: Set<SidebarItem> {
        [
            viewModel.selectedCategory.map(SidebarItem.category) ?? .allCategories,
            viewModel.selectedTechStack.map(SidebarItem.stack) ?? .allStacks,
        ]
    }
}

private enum SidebarItem: Hashable {
    case allCategories
    case category(AppCategory)
    case allStacks
    case stack(TechStack)
}

#Preview {
    let viewModel = CategoryViewModel()
    viewModel.apps = AppInfo.samples
    return CategoryView(viewModel: viewModel)
        .frame(width: 220, height: 500)
}
