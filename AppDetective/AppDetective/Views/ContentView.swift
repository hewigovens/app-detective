import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    @ObservedObject private var categoryViewModel: CategoryViewModel
    @EnvironmentObject private var updateService: UpdateService
    @State private var isShowingUpdateError: Bool = false

    init(viewModel: ContentViewModel) {
        self.viewModel = viewModel
        self._categoryViewModel = ObservedObject(wrappedValue: viewModel.categoryViewModel)
    }

    var body: some View {
        let isLoading = viewModel.isLoading
        let errorMessage = viewModel.errorMessage

        NavigationSplitView {
            if #available(macOS 15.0, *) {
                CategoryView(viewModel: categoryViewModel)
                    .navigationTitle("Filters")
                    .navigationSplitViewColumnWidth(220)
                    .containerBackground(.ultraThinMaterial, for: .window)
            } else {
                CategoryView(viewModel: categoryViewModel)
                    .navigationTitle("Filters")
                    .navigationSplitViewColumnWidth(220)
            }
        } detail: {
            ZStack {
                VStack {
                    if let msg = errorMessage {
                        Text("Error: \(msg)")
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        if viewModel.appResults.isEmpty && !isLoading {
                            Text("No apps found or scan not started.")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if !viewModel.appResults.isEmpty {
                            List(categoryViewModel.filteredApps) { app in
                                AppListCell(appInfo: app)
                            }
                            .environmentObject(viewModel)
                            HStack(spacing: 4) {
                                if let selectedCategory = categoryViewModel.selectedCategory {
                                    Text("Showing \(categoryViewModel.filteredApps.count) apps in \(selectedCategory.description)")
                                } else {
                                    Text("Showing \(categoryViewModel.filteredApps.count) of \(viewModel.appResults.count) apps")
                                }

                                if let selectedTechStack = categoryViewModel.selectedTechStack {
                                    Text(
                                        "with \(TechStack.flagNames[selectedTechStack.rawValue] ?? "Unknown")"
                                    )
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 8)
                        } else {
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isLoading {
                    ProgressView("Scanning...")
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .toolbar {
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
                        
                        Button {
                            updateService.checkForUpdates()
                        } label: {
                            if updateService.isCheckingForUpdates {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "arrow.down.circle")
                            }
                        }
                        .help(updateService.isCheckingForUpdates ? "Checking for updates..." : "Check for application updates")
                        .disabled(updateService.isCheckingForUpdates)

                        Divider()
                        
                        Button {
                            NSWorkspace.shared.open(URL(string: Constants.sponsorLink)!)
                        } label: {
                            Image(systemName: "heart.circle")
                        }
                        .help("Buy author a Coffe if you find this app useful")
                        Button {
                            NSWorkspace.shared.open(URL(string: Constants.githubLink)!)
                        } label: {
                            Image(systemName: "curlybraces")
                        }
                        .help("Star on GitHub")
                    }
                }
            }
            .background(Color.clear)
            .frame(minWidth: 500, minHeight: 400)
            .animation(.easeInOut(duration: 0.2), value: categoryViewModel.selectedCategory)
            .animation(.easeInOut(duration: 0.2), value: categoryViewModel.selectedTechStack)
        }
        .onChange(of: updateService.lastUpdateError) { _, newError in
            isShowingUpdateError = newError != nil
        }
        .alert("Update Failed", isPresented: $isShowingUpdateError, presenting: updateService.lastUpdateError) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let dummyURL = URL(fileURLWithPath: "/Applications")
        let dummyViewModel = ContentViewModel(folderURL: dummyURL)

        let sampleApps = [
            AppInfo(name: "Preview", path: "/Applications/Preview.app", techStacks: .swiftUI, category: .utilities),
            AppInfo(name: "Xcode", path: "/Applications/Xcode.app", techStacks: .appKit, category: .developerTools),
            AppInfo(name: "Safari", path: "/Applications/Safari.app", techStacks: .appKit, category: .productivity),
            AppInfo(name: "Music", path: "/Applications/Music.app", techStacks: .catalyst, category: .music),
            AppInfo(name: "Notes", path: "/Applications/Notes.app", techStacks: .catalyst, category: .productivity)
        ]

        dummyViewModel.appResults = sampleApps
        dummyViewModel.categoryViewModel.updateCategories(with: sampleApps)

        return ContentView(viewModel: dummyViewModel)
            .environmentObject(UpdateService(preview: true))
    }
}
