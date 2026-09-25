import DetectiveCore
import SwiftUI

struct ContentView: View {
    let viewModel: ContentViewModel

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
            .searchable(text: $categoryViewModel.searchText, prompt: "Name or bundle ID")
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
        ToolbarItemGroup(placement: .primaryAction) {
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
            } label: {
                Label("Folders", systemImage: "folder")
            }
            .help("Choose which folders to scan")
            .disabled(viewModel.isLoading)

            Button("Rescan", systemImage: "arrow.clockwise") {
                viewModel.clearCachesAndRescan()
            }
            .help("Clear the cache and rescan")
            .disabled(viewModel.isLoading)

            Button("Inspector", systemImage: "sidebar.trailing") {
                viewModel.isShowingInspector.toggle()
            }
            .help("Show or hide the selected app's details")
        }
    }
}

#Preview {
    let viewModel = ContentViewModel(startupFolderURL: URL(fileURLWithPath: "/Applications"))
    viewModel.appResults = AppInfo.samples
    return ContentView(viewModel: viewModel)
}
