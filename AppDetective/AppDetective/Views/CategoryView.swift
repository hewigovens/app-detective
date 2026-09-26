import DetectiveCore
import LSAppCategory
import SwiftUI

struct CategoryView: View {
    let viewModel: CategoryViewModel

    var body: some View {
        List(selection: selection) {
            Section("Categories") {
                Label {
                    Text("All Apps")
                } icon: {
                    SidebarIcon(systemName: "square.grid.2x2")
                }
                .badge(viewModel.apps.count)
                    .tag(SidebarItem.allCategories)

                ForEach(viewModel.sortedCategories) { category in
                    Label {
                        Text(category.description)
                    } icon: {
                        SidebarIcon(systemName: category.sfSymbol)
                    }
                    .badge(viewModel.categoryCounts[category] ?? 0)
                        .tag(SidebarItem.category(category))
                }
            }

            Section("Tech Stacks") {
                Label {
                    Text("All Stacks")
                } icon: {
                    SidebarIcon(systemName: "square.stack.3d.up")
                }
                .tag(SidebarItem.allStacks)

                ForEach(viewModel.sortedStacks, id: \.self) { stack in
                    Label {
                        Text(stack.displayName)
                    } icon: {
                        Circle()
                            .fill(stack.mainColor)
                            .frame(width: 9, height: 9)
                            .frame(width: SidebarIcon.width)
                    }
                    .badge(viewModel.stackCounts[stack] ?? 0)
                    .tag(SidebarItem.stack(stack))
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

// SF Symbols differ in size and width, so each one is scaled to fit the same box inside the same slot,
// which keeps the titles aligned and the icons visually even. The sidebar's own label style still
// colors it, including the white-on-selection swap.
private struct SidebarIcon: View {
    static let width: CGFloat = 20
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .frame(width: Self.width, height: 18)
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
