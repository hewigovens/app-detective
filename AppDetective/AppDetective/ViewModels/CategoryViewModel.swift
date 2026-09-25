import DetectiveCore
import Foundation
import LSAppCategory
import SwiftUI

@MainActor
@Observable
final class CategoryViewModel {
    var apps: [AppInfo] = [] {
        didSet { refresh() }
    }
    var selectedCategory: AppCategory? {
        didSet { refresh() }
    }
    var selectedTechStack: TechStack? {
        didSet { refresh() }
    }
    var searchText = "" {
        didSet { refresh() }
    }

    private(set) var filteredApps: [AppInfo] = []
    private(set) var sortedCategories: [AppCategory] = []
    private(set) var categoryCounts: [AppCategory: Int] = [:]
    private(set) var stackCounts: [TechStack: Int] = [:]

    func resetFilters() {
        selectedCategory = nil
        selectedTechStack = nil
    }

    private func refresh() {
        categoryCounts = apps.reduce(into: [:]) { counts, app in counts[app.category, default: 0] += 1 }
        sortedCategories = categoryCounts.keys.sorted { $0.description < $1.description }

        let inCategory = selectedCategory.map { category in apps.filter { $0.category == category } } ?? apps
        stackCounts = Dictionary(uniqueKeysWithValues: TechStack.allStacks.map { stack in
            (stack, inCategory.filter { $0.techStacks.contains(stack) }.count)
        })

        let query = searchText.lowercased()
        filteredApps = inCategory.filter { app in
            let matchesStack = selectedTechStack.map(app.techStacks.contains) ?? true
            let matchesQuery = query.isEmpty
                || app.name.lowercased().contains(query)
                || (app.bundleId?.lowercased().contains(query) ?? false)
            return matchesStack && matchesQuery
        }
    }
}
