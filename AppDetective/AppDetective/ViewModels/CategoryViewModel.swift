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
    // At most one trait per kind; an app must have all of them.
    var selectedTraits: [TraitKind: Trait] = [:] {
        didSet { refresh() }
    }
    var searchText = "" {
        didSet { refresh() }
    }
    var selectedAppID: AppInfo.ID? {
        didSet { selectedApp = apps.first { $0.id == selectedAppID } }
    }

    private(set) var filteredApps: [AppInfo] = []
    private(set) var selectedApp: AppInfo?
    private(set) var sortedCategories: [AppCategory] = []
    private(set) var categoryCounts: [AppCategory: Int] = [:]
    private(set) var traitCounts: [Trait: Int] = [:]
    private(set) var sortedTraits: [TraitKind: [Trait]] = [:]

    func resetFilters() {
        selectedCategory = nil
        selectedTraits = [:]
    }

    private func refresh() {
        selectedApp = apps.first { $0.id == selectedAppID }
        categoryCounts = apps.reduce(into: [:]) { counts, app in counts[app.category, default: 0] += 1 }
        sortedCategories = categoryCounts.keys.sorted { $0.description < $1.description }

        let inCategory = selectedCategory.map { category in apps.filter { $0.category == category } } ?? apps
        traitCounts = inCategory.reduce(into: [:]) { counts, app in
            for trait in app.traits {
                counts[trait, default: 0] += 1
            }
        }
        // Most common first; catalog order breaks ties so the list is stable. A selected trait the category lacks
        // stays listed, at zero, so its filter can still be cleared.
        let present = traitCounts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.map(\.key)
            + selectedTraits.values.filter { traitCounts[$0] == nil }
        sortedTraits = Dictionary(grouping: present, by: \.kind)

        let query = searchText.lowercased()
        filteredApps = inCategory.filter { app in
            let matchesTraits = selectedTraits.values.allSatisfy(app.traits.contains)
            let matchesQuery = query.isEmpty
                || app.name.lowercased().contains(query)
                || (app.bundleId?.lowercased().contains(query) ?? false)
            return matchesTraits && matchesQuery
        }
    }
}
