import AppKit
import DetectiveCore
import SwiftUI

struct ContentView: View {
    let viewModel: ContentViewModel
    @State private var isSearchVisible = false

    private var categoryViewModel: CategoryViewModel {
        viewModel.categoryViewModel
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var categoryViewModel = categoryViewModel

        NavigationSplitView {
            CategoryView(viewModel: categoryViewModel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            VStack(spacing: 0) {
                if let warningMessage = viewModel.warningMessage {
                    Label(warningMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.yellow.opacity(0.12))
                        .accessibilityIdentifier("scan-warning-message")
                }
                content
            }
            .navigationTitle(viewModel.title)
            .navigationSubtitle(subtitle)
            .toolbar { toolbar }
            .inspector(isPresented: $viewModel.isShowingInspector) {
                AppDetailView(app: categoryViewModel.selectedApp)
                    .inspectorColumnWidth(min: 280, ideal: 340, max: 520)
            }
            .frame(minWidth: 500, minHeight: 400)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView {
                Label("No Apps", systemImage: "questionmark.app.dashed")
            } description: {
                Text(errorMessage)
                    .accessibilityIdentifier("scan-error-message")
            }
        } else if viewModel.appResults.isEmpty {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("No Apps", systemImage: "app.dashed")
            }
        } else if categoryViewModel.filteredApps.isEmpty {
            ContentUnavailableView.search(text: categoryViewModel.searchText)
        } else {
            @Bindable var categoryViewModel = categoryViewModel
            List(categoryViewModel.filteredApps, selection: $categoryViewModel.selectedAppID) { app in
                AppListCell(appInfo: app)
                    .listRowBackground(rowBackground(isSelected: app.id == categoryViewModel.selectedAppID))
            }
            // A tap gesture on the rows would delay selection; the list reports double-clicks as its primary action.
            .contextMenu(forSelectionType: AppInfo.ID.self) { paths in
                Button("Show in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
                }
            } primaryAction: { paths in
                if let path = paths.first {
                    categoryViewModel.selectedAppID = path
                }
                viewModel.isShowingInspector.toggle()
            }
        }
    }

    // The system highlight is accent when the list is focused and gray otherwise, and colored tags are
    // unreadable on the accent. An opaque tint covers it, so a selected row always looks the same.
    @ViewBuilder
    private func rowBackground(isSelected: Bool) -> some View {
        if isSelected {
            Color(nsColor: .controlBackgroundColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.14))
                        .padding(.horizontal, 8)
                }
        }
    }

    private var subtitle: String {
        if let progress = viewModel.progress {
            return "Scanning \(Int(progress * 100))%"
        }
        let shown = categoryViewModel.filteredApps.count
        let total = viewModel.appResults.count
        return shown == total ? "\(total) apps" : "\(shown) of \(total) apps"
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // Separate items keep their identity, so toggling the search field doesn't redraw the menu.
        ToolbarItem(placement: .primaryAction) {
            searchItem
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section("Scanned Folders") {
                    ForEach(viewModel.folderURLs, id: \.self) { url in
                        Button("Remove \(url.lastPathComponent)", systemImage: "minus.circle") {
                            viewModel.removeFolder(url)
                        }
                    }
                }
                Button("Add Folder…", systemImage: "plus") {
                    viewModel.addFolders()
                }
                Divider()
                Button("Rescan All Folders", systemImage: "arrow.clockwise") {
                    viewModel.clearCachesAndRescan()
                }
            } label: {
                Label("Manage", systemImage: "folder.badge.gearshape")
            }
            .help("Add or remove folders, or clear the cache and rescan")
            .disabled(viewModel.isLoading)
        }
    }

    @ViewBuilder
    private var searchItem: some View {
        if isSearchVisible {
            @Bindable var categoryViewModel = categoryViewModel
            ToolbarSearchField(text: $categoryViewModel.searchText, onCancel: hideSearch)
                .accessibilityIdentifier("search-field")
        } else {
            Button("Search", systemImage: "magnifyingglass") {
                isSearchVisible = true
            }
            .keyboardShortcut("f")
            .help("Search by name or bundle ID")
        }
    }

    private func hideSearch() {
        categoryViewModel.searchText = ""
        isSearchVisible = false
    }
}

#Preview {
    let viewModel = ContentViewModel(startupFolderURL: URL(fileURLWithPath: "/Applications"))
    viewModel.appResults = AppInfo.samples
    return ContentView(viewModel: viewModel)
}
