//
//  ContentView.swift
//  AppDetective
//
//  Created by hewig on 4/29/25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        // Access properties outside the conditional structure
        let isLoading = viewModel.isLoading
        let errorMessage = viewModel.errorMessage

        VStack {
            // Removed the ProgressView block that was here
            if let msg = errorMessage { // Adjusted the conditional flow
                Text("Error: \(msg)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                if viewModel.appResults.isEmpty && !isLoading { // Check isLoading here as well
                    Text("No apps found or scan not started.")
                } else if !viewModel.appResults.isEmpty { // Show list only if not empty
                    List(viewModel.appResults) { app in
                        AppListCell(appInfo: app)
                    }
                    .environmentObject(viewModel) // Make VM available to cells
                } else if isLoading { // Add a simple loading text if needed, or leave empty
                    Text("Scanning...") // Optional: Add a simple loading indicator
                }
            }
        }
        .navigationTitle(viewModel.navigationTitle) // Use the viewModel's published title
        .background(.regularMaterial) // Add vibrant background
        .frame(minWidth: 500, minHeight: 400) // Set a reasonable default size
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let dummyURL = URL(fileURLWithPath: "/Applications") // Use a valid-looking path
        let dummyViewModel = ContentViewModel(folderURL: dummyURL)
        // Optionally trigger a dummy scan or populate dummy data for preview:
        // dummyViewModel.appResults = [AppInfo(name: "Preview App", path: "/Applications/Preview.app", techStack: "SwiftUI")]

        return ContentView(viewModel: dummyViewModel)
    }
}
