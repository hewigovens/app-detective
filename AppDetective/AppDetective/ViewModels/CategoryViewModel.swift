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
        traitCounts = Dictionary(uniqueKeysWithValues: Trait.all.map { trait in
            (trait, inCategory.filter { $0.traits.contains(trait) }.count)
        })
        // Most common first; catalog order breaks ties so the list is stable.
        let present = Trait.all.enumerated()
            .filter { traitCounts[$0.element, default: 0] > 0 }
            .sorted { (traitCounts[$0.element]!, $1.offset) > (traitCounts[$1.element]!, $0.offset) }
            .map(\.element)
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
