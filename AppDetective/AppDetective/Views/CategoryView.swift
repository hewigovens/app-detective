import LSAppCategory
import SwiftUI

// MARK: - Category Button View

struct CategoryButtonView: View {
    let category: AppCategory?
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(category?.emoji ?? "🌐")
                    .font(.system(size: 14))

                Text(category?.description ?? "All Apps")
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))

                Spacer()

                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(5)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                    )
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(isSelected ?
            Color.accentColor.opacity(0.15) :
            Color.clear)
    }
}

// MARK: - Tech Stack Button View

struct TechStackButtonView: View {
    let techStack: TechStack?
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let stack = techStack {
                    Circle()
                        .fill(stack.mainColor)
                        .frame(width: 12, height: 12)

                    Text(TechStack.flagNames[stack.rawValue] ?? "Unknown")
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                } else {
                    Text("All")
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                }

                Spacer()

                if techStack != nil {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(0.2))
                        )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(isSelected ?
            Color.accentColor.opacity(0.15) :
            Color.clear)
    }
}

// MARK: - Category Section View

struct CategorySectionView: View {
    @ObservedObject var viewModel: CategoryViewModel

    var body: some View {
        Section {
            CategoryButtonView(
                category: nil,
                count: viewModel.allApps.count,
                isSelected: viewModel.selectedCategory == nil,
                action: { viewModel.selectCategory(nil) }
            )

            ForEach(viewModel.sortedCategories) { category in
                CategoryButtonView(
                    category: category,
                    count: viewModel.count(for: category),
                    isSelected: viewModel.selectedCategory == category,
                    action: { viewModel.selectCategory(category) }
                )
            }
        } header: {
            Text("Categories")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Tech Stack Section View

struct TechStackSectionView: View {
    @ObservedObject var viewModel: CategoryViewModel

    var body: some View {
        Section {
            TechStackButtonView(
                techStack: nil,
                count: 0,
                isSelected: viewModel.selectedTechStack == nil,
                action: { viewModel.selectTechStack(nil) }
            )

            Group {
                createTechStackButtons([.swiftUI, .appKit, .catalyst])
            }

            Group {
                createTechStackButtons([.electron, .cef, .flutter, .qt, .reactNative,
                                        .java, .python, .xamarin, .tauri, .wxWidgets])
            }
        } header: {
            Text("Tech Stacks")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
    }

    @ViewBuilder
    private func createTechStackButtons(_ stacks: [TechStack]) -> some View {
        ForEach(stacks, id: \.self) { techStack in
            let count = viewModel.selectedCategory != nil
                ? viewModel.count(for: viewModel.selectedCategory!, techStack: techStack)
                : viewModel.allApps.filter { $0.techStacks.contains(techStack) }.count

            if count > 0 {
                TechStackButtonView(
                    techStack: techStack,
                    count: count,
                    isSelected: viewModel.selectedTechStack == techStack,
                    action: { viewModel.selectTechStack(techStack) }
                )
            }
        }
    }
}

// MARK: - Main Category View

struct CategoryView: View {
    @ObservedObject var viewModel: CategoryViewModel

    var body: some View {
        List {
            CategorySectionView(viewModel: viewModel)
            TechStackSectionView(viewModel: viewModel)
        }
        .listStyle(SidebarListStyle())
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedCategory)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedTechStack)
    }
}

// Preview provider for CategoryView
struct CategoryView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = CategoryViewModel()

        let sampleApps = [
            AppInfo(name: "Preview", path: "/Applications/Preview.app", techStacks: .swiftUI, category: .utilities),
            AppInfo(name: "Xcode", path: "/Applications/Xcode.app", techStacks: .appKit, category: .developerTools),
            AppInfo(name: "Safari", path: "/Applications/Safari.app", techStacks: .appKit, category: .productivity),
            AppInfo(name: "Music", path: "/Applications/Music.app", techStacks: .catalyst, category: .music),
            AppInfo(name: "Notes", path: "/Applications/Notes.app", techStacks: .catalyst, category: .productivity),
            AppInfo(name: "Terminal", path: "/Applications/Terminal.app", techStacks: .appKit, category: .developerTools)
        ]

        viewModel.updateCategories(with: sampleApps)

        return NavigationView {
            CategoryView(viewModel: viewModel)
                .navigationTitle("Categories")
        }
    }
}
