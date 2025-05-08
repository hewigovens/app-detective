import SwiftUI
import LSAppCategory

struct CategoryView: View {
    @ObservedObject var viewModel: CategoryViewModel

    var body: some View {
        List {
            // Category section
            Section {
                // All apps option
                Button(action: {
                    viewModel.selectCategory(nil)
                }) {
                    HStack(spacing: 12) {
                        Text("🌐")
                            .font(.title2)

                        Text("All Apps")
                            .fontWeight(viewModel.selectedCategory == nil ? .bold : .regular)

                        Spacer()

                        Text("\(viewModel.allApps.count)")
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.2))
                            )
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
                .listRowBackground(viewModel.selectedCategory == nil ?
                                  Color.accentColor.opacity(0.15) :
                                  Color.clear)

                // Category list
                ForEach(viewModel.sortedCategories) { category in
                    Button(action: {
                        viewModel.selectCategory(category)
                    }) {
                        HStack(spacing: 12) {
                            Text(category.emoji)
                                .font(.title2)

                            Text(category.displayName)
                                .fontWeight(viewModel.selectedCategory == category ? .bold : .regular)

                            Spacer()

                            Text("\(viewModel.count(for: category))")
                                .foregroundColor(.secondary)
                                .padding(6)
                                .background(
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.2))
                                )
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(viewModel.selectedCategory == category ?
                                      Color.accentColor.opacity(0.15) :
                                      Color.clear)
                }
            } header: {
                Text("Categories")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            // Tech Stack section
            Section {
                // All tech stacks option
                Button(action: {
                    viewModel.selectTechStack(nil)
                }) {
                    HStack(spacing: 12) {
                        Text("All")
                            .fontWeight(viewModel.selectedTechStack == nil ? .bold : .regular)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .listRowBackground(viewModel.selectedTechStack == nil ?
                                  Color.accentColor.opacity(0.15) :
                                  Color.clear)

                // Native frameworks
                Group {
                    createTechStackButton(.swiftUI)
                    createTechStackButton(.appKit)
                    createTechStackButton(.catalyst)
                }

                // Cross-platform frameworks
                Group {
                    createTechStackButton(.electron)
                    createTechStackButton(.cef)
                    createTechStackButton(.flutter)
                    createTechStackButton(.qt)
                    createTechStackButton(.reactNative)
                    createTechStackButton(.java)
                    createTechStackButton(.python)
                    createTechStackButton(.xamarin)
                    createTechStackButton(.tauri)
                    createTechStackButton(.wxWidgets)
                }
            } header: {
                Text("Tech Stacks")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
        .listStyle(SidebarListStyle())
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedCategory)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedTechStack)
    }

    // Helper function to create a tech stack button
    private func createTechStackButton(_ techStack: TechStack) -> some View {
        // Get count based on current filter context
        let count = viewModel.selectedCategory != nil
            ? viewModel.count(for: viewModel.selectedCategory!, techStack: techStack)
            : viewModel.allApps.filter { $0.techStacks.contains(techStack) }.count

        // Only show tech stacks that have at least one app
        return Group {
            if count > 0 {
                Button(action: {
                    viewModel.selectTechStack(techStack)
                }) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(techStack.mainColor)
                            .frame(width: 12, height: 12)

                        Text(TechStack.flagNames[techStack.rawValue] ?? "Unknown")
                            .fontWeight(viewModel.selectedTechStack == techStack ? .bold : .regular)

                        Spacer()

                        Text("\(count)")
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.2))
                            )
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .listRowBackground(viewModel.selectedTechStack == techStack ?
                                  Color.accentColor.opacity(0.15) :
                                  Color.clear)
            }
        }
    }
}

// Preview provider for CategoryView
struct CategoryView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = CategoryViewModel()

        // Add sample data
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
