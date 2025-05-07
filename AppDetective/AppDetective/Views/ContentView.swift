//
//  ContentView.swift
//  AppDetective
//
//  Created by hewig on 4/29/25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    @ObservedObject private var categoryViewModel: CategoryViewModel

    init(viewModel: ContentViewModel) {
        self.viewModel = viewModel
        self._categoryViewModel = ObservedObject(wrappedValue: viewModel.categoryViewModel)
    }

    var body: some View {
        let isLoading = viewModel.isLoading
        let errorMessage = viewModel.errorMessage

        NavigationSplitView {
            // Sidebar with categories and tech stacks
            CategoryView(viewModel: categoryViewModel)
                .navigationTitle("Filters")
        } detail: {
            VStack {
                if let msg = errorMessage {
                    Text("Error: \(msg)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    if viewModel.appResults.isEmpty && !isLoading {
                        Text("No apps found or scan not started.")
                    } else if !viewModel.appResults.isEmpty {
                        // Display filtered apps based on selected category and tech stack
                        List(categoryViewModel.filteredApps) { app in
                            AppListCell(appInfo: app)
                        }
                        .environmentObject(viewModel)

                        // Add a footer showing the current filter
                        HStack(spacing: 4) {
                            if let selectedCategory = categoryViewModel.selectedCategory {
                                Text("Showing \(categoryViewModel.filteredApps.count) apps in \(selectedCategory.displayName)")
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
                    } else if isLoading {
                        ProgressView("Scanning...")
                    }
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
                            Text("Select Folder")
                        }
                        .help("Select a new folder to scan for applications")
                        .disabled(viewModel.isLoading)

                        Button {
                            viewModel.clearCachesAndRescan()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                            Text("Rescan")
                        }
                        .help("Clear cache and rescan the selected folder")
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            .background(.regularMaterial)
            .frame(minWidth: 500, minHeight: 400)
            .animation(.easeInOut(duration: 0.2), value: categoryViewModel.selectedCategory)
            .animation(.easeInOut(duration: 0.2), value: categoryViewModel.selectedTechStack)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let dummyURL = URL(fileURLWithPath: "/Applications")
        let dummyViewModel = ContentViewModel(folderURL: dummyURL)

        // Add sample data for the preview
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
    }
}
