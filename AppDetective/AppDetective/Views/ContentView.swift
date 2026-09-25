import DetectiveCore
import SwiftUI

struct ContentView: View {
    let viewModel: ContentViewModel

    private var categoryViewModel: CategoryViewModel {
        viewModel.categoryViewModel
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            ZStack {
                VStack {
                    if let errorMessage = viewModel.errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                            .padding()
                            .accessibilityIdentifier("scan-error-message")
                    } else {
                        if let warningMessage = viewModel.warningMessage {
                            Text(warningMessage)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.12))
                                .accessibilityIdentifier("scan-warning-message")
                        }

                        if viewModel.appResults.isEmpty {
                            if !viewModel.isLoading {
                                Text("No apps found or scan not started.")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        } else {
                            List(categoryViewModel.filteredApps) { app in
                                AppListCell(appInfo: app)
                            }
                            Text(summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if viewModel.isLoading {
                    ProgressView("Scanning…")
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .toolbar { toolbar }
            .frame(minWidth: 500, minHeight: 400)
            .animation(.easeInOut(duration: 0.2), value: categoryViewModel.selectedCategory)
            .animation(.easeInOut(duration: 0.2), value: categoryViewModel.selectedTechStack)
        }
    }

    private var sidebar: some View {
        CategoryView(viewModel: categoryViewModel)
            .navigationTitle("Filters")
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        @Bindable var categoryViewModel = categoryViewModel
        ToolbarItem(placement: .automatic) {
            TextField("Filter by name or bundle ID", text: $categoryViewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
        }
        ToolbarItem(placement: .primaryAction) {
            HStack {
                Button {
                    viewModel.selectNewFolderAndScan()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("Select a new folder to scan for applications")
                .disabled(viewModel.isLoading)

                Button {
                    viewModel.clearCachesAndRescan()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Clear cache and rescan the selected folder")
                .disabled(viewModel.isLoading)

                Divider()

                Button {
                    NSWorkspace.shared.open(URL(string: Constants.sponsorLink)!)
                } label: {
                    Image(systemName: "heart.circle")
                }
                .help("Buy author a Coffee if you find this app useful")
            }
        }
    }

    private var summary: String {
        let shown = categoryViewModel.filteredApps.count
        var parts = if let category = categoryViewModel.selectedCategory {
            ["Showing \(shown) apps in \(category.description)"]
        } else {
            ["Showing \(shown) of \(viewModel.appResults.count) apps"]
        }
        if let stack = categoryViewModel.selectedTechStack {
            parts.append("with \(stack.displayName)")
        }
        if !categoryViewModel.searchText.isEmpty {
            parts.append("matching \"\(categoryViewModel.searchText)\"")
        }
        return parts.joined(separator: " ")
    }
}

#Preview {
    let viewModel = ContentViewModel(startupFolderURL: URL(fileURLWithPath: "/Applications"))
    viewModel.appResults = AppInfo.samples
    return ContentView(viewModel: viewModel)
}
