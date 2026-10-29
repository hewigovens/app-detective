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

            ForEach(TraitKind.allCases, id: \.self) { kind in
                if let traits = viewModel.sortedTraits[kind] {
                    Section(kind.pluralName) {
                        Label {
                            Text("All")
                        } icon: {
                            SidebarIcon(systemName: "square.stack.3d.up")
                        }
                        .tag(SidebarItem.allTraits(kind))

                        ForEach(traits) { trait in
                            Label {
                                Text(trait.name)
                            } icon: {
                                Circle()
                                    .fill(trait.color)
                                    .frame(width: 9, height: 9)
                                    .frame(width: SidebarIcon.width)
                            }
                            .badge(viewModel.traitCounts[trait] ?? 0)
                            .tag(SidebarItem.trait(trait))
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    // Category and trait filters combine, so each section keeps its own selected row.
    private var selection: Binding<Set<SidebarItem>> {
        Binding {
            selectedItems
        } set: { items in
            for item in items.subtracting(selectedItems) {
                switch item {
                case .allCategories: viewModel.selectedCategory = nil
                case let .category(category): viewModel.selectedCategory = category
                case let .allTraits(kind): viewModel.selectedTraits[kind] = nil
                case let .trait(trait): viewModel.selectedTraits[trait.kind] = trait
                }
            }
        }
    }

    // Only active trait filters are highlighted; highlighting every section's unfiltered "All" row filled the sidebar.
    private var selectedItems: Set<SidebarItem> {
        let category = viewModel.selectedCategory.map(SidebarItem.category) ?? .allCategories
        return Set([category] + viewModel.selectedTraits.values.map(SidebarItem.trait))
    }
}

// SF Symbols differ in size and width, so each one is scaled to fit the same box inside the same slot,
// which keeps the titles aligned and the icons visually even. Secondary rather than the sidebar's accent
// tint, which colored every row and outweighed the trait dots; it still turns white on selection.
private struct SidebarIcon: View {
    static let width: CGFloat = 20
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .frame(width: Self.width, height: 18)
            .foregroundStyle(.secondary)
    }
}

private enum SidebarItem: Hashable {
    case allCategories
    case category(AppCategory)
    case allTraits(TraitKind)
    case trait(Trait)
}

#Preview {
    let viewModel = CategoryViewModel()
    viewModel.apps = AppInfo.samples
    return CategoryView(viewModel: viewModel)
        .frame(width: 220, height: 500)
}
