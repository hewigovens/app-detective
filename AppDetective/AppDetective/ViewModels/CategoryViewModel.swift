import Foundation
import SwiftUI

class CategoryViewModel: ObservableObject {
    @Published var categories: [Category: [AppInfo]] = [:] // Maps categories to arrays of apps
    @Published var allApps: [AppInfo] = []
    @Published var selectedCategory: Category? // Currently selected category
    @Published var selectedTechStack: TechStack? // Currently selected tech stack for filtering

    // Returns all categories, sorted alphabetically
    var sortedCategories: [Category] {
        Array(categories.keys).sorted { $0.displayName < $1.displayName }
    }

    // Returns apps for the selected category and tech stack
    var filteredApps: [AppInfo] {
        var apps: [AppInfo] = []

        // First filter by category
        if let selectedCategory = selectedCategory {
            apps = categories[selectedCategory] ?? []
        } else {
            apps = allApps
        }

        // Then filter by tech stack if one is selected
        if let techStack = selectedTechStack {
            return apps.filter { $0.techStacks.contains(techStack) }
        }

        return apps
    }

    // Update categories based on a new list of apps
    func updateCategories(with apps: [AppInfo]) {
        allApps = apps

        // Reset categories and rebuild from scratch
        categories = [:]

        for app in apps {
            if categories[app.category] == nil {
                categories[app.category] = []
            }
            categories[app.category]?.append(app)
        }

        // If no category is selected or the selected category no longer exists, select the first one
        if selectedCategory == nil || (selectedCategory != nil && categories[selectedCategory!] == nil) {
            selectedCategory = sortedCategories.first
        }
    }

    // Select a specific category
    func selectCategory(_ category: Category?) {
        selectedCategory = category
    }

    // Select a specific tech stack
    func selectTechStack(_ techStack: TechStack?) {
        selectedTechStack = techStack
    }

    // Get a count of apps in each category
    func count(for category: Category) -> Int {
        categories[category]?.count ?? 0
    }

    // Get a count of apps for a specific tech stack in a category
    func count(for category: Category, techStack: TechStack) -> Int {
        (categories[category] ?? []).filter { $0.techStacks.contains(techStack) }.count
    }
}
