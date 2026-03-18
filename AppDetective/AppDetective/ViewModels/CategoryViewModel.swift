import Foundation
import LSAppCategory
import SwiftUI

class CategoryViewModel: ObservableObject {
    @Published var categories: [AppCategory: [AppInfo]] = [:]
    @Published var allApps: [AppInfo] = []
    @Published var selectedCategory: AppCategory?
    @Published var selectedTechStack: TechStack?
    @Published var searchText: String = ""

    var sortedCategories: [AppCategory] {
        Array(categories.keys).sorted { $0.description < $1.description }
    }

    var filteredApps: [AppInfo] {
        var apps: [AppInfo] = []

        if let selectedCategory = selectedCategory {
            apps = categories[selectedCategory] ?? []
        } else {
            apps = allApps
        }

        if let techStack = selectedTechStack {
            apps = apps.filter { $0.techStacks.contains(techStack) }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            apps = apps.filter {
                $0.name.lowercased().contains(query) ||
                ($0.bundleId?.lowercased().contains(query) ?? false)
            }
        }

        return apps
    }

    func updateCategories(with apps: [AppInfo]) {
        allApps = apps
        categories = [:]

        for app in apps {
            if categories[app.category] == nil {
                categories[app.category] = []
            }
            categories[app.category]?.append(app)
        }

        selectedCategory = nil
        selectedTechStack = nil
    }

    func selectCategory(_ category: AppCategory?) {
        selectedCategory = category
    }

    func selectTechStack(_ techStack: TechStack?) {
        selectedTechStack = techStack
    }

    func count(for category: AppCategory) -> Int {
        categories[category]?.count ?? 0
    }

    func count(for category: AppCategory, techStack: TechStack) -> Int {
        (categories[category] ?? []).filter { $0.techStacks.contains(techStack) }.count
    }
}
