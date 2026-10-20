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

    @Test("Counts apps per category and per trait")
    func counts() {
        let viewModel = makeViewModel()

        #expect(viewModel.categoryCounts[.productivity] == 1)
        #expect(viewModel.traitCounts[.appKit] == 2)
        #expect(viewModel.filteredApps.count == AppInfo.samples.count)
        #expect(viewModel.sortedTraits[.ui] == [.appKit, .swiftUI, .catalyst, .electron])
        #expect(viewModel.sortedTraits[.language] == [.swift, .objectiveC])
    }

    @Test("Combines category, trait, and search filters")
    func filters() {
        let viewModel = makeViewModel()

        viewModel.selectedTraits[.ui] = .appKit
        #expect(viewModel.filteredApps.map(\.name) == ["Xcode", "Safari"])

        viewModel.selectedTraits[.language] = .swift
        #expect(viewModel.filteredApps.map(\.name) == ["Xcode"])
        viewModel.selectedTraits[.language] = nil

        viewModel.selectedCategory = .productivity
        #expect(viewModel.filteredApps.map(\.name) == ["Safari"])
        #expect(viewModel.traitCounts[.appKit] == 1)

        viewModel.selectedCategory = nil
        viewModel.searchText = "com.apple.dt"
        #expect(viewModel.filteredApps.map(\.name) == ["Xcode"])
    }

    @Test("Resetting clears category and traits but keeps the search")
    func resetFilters() {
        let viewModel = makeViewModel()
        viewModel.selectedCategory = .music
        viewModel.selectedTraits[.ui] = .catalyst
        viewModel.searchText = "Mu"

        viewModel.resetFilters()

        #expect(viewModel.selectedCategory == nil)
        #expect(viewModel.selectedTraits.isEmpty)
        #expect(viewModel.filteredApps.map(\.name) == ["Music"])
    }
}
