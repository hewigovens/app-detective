@testable import AppDetective
import DetectiveCore
import Testing

@MainActor
struct CategoryViewModelTests {
    private func makeViewModel() -> CategoryViewModel {
        let viewModel = CategoryViewModel()
        viewModel.apps = AppInfo.samples
        return viewModel
    }

    @Test("Counts apps per category and per stack")
    func counts() {
        let viewModel = makeViewModel()

        #expect(viewModel.categoryCounts[.productivity] == 1)
        #expect(viewModel.stackCounts[.appKit] == 2)
        #expect(viewModel.filteredApps.count == AppInfo.samples.count)
        #expect(viewModel.sortedStacks == [.appKit, .swiftUI, .catalyst, .electron])
    }

    @Test("Combines category, stack, and search filters")
    func filters() {
        let viewModel = makeViewModel()

        viewModel.selectedTechStack = .appKit
        #expect(viewModel.filteredApps.map(\.name) == ["Xcode", "Safari"])

        viewModel.selectedCategory = .productivity
        #expect(viewModel.filteredApps.map(\.name) == ["Safari"])
        #expect(viewModel.stackCounts[.appKit] == 1)

        viewModel.selectedCategory = nil
        viewModel.searchText = "com.apple.dt"
        #expect(viewModel.filteredApps.map(\.name) == ["Xcode"])
    }

    @Test("Resetting clears category and stack but keeps the search")
    func resetFilters() {
        let viewModel = makeViewModel()
        viewModel.selectedCategory = .music
        viewModel.selectedTechStack = .catalyst
        viewModel.searchText = "Mu"

        viewModel.resetFilters()

        #expect(viewModel.selectedCategory == nil)
        #expect(viewModel.selectedTechStack == nil)
        #expect(viewModel.filteredApps.map(\.name) == ["Music"])
    }
}
