import Foundation
import LSAppCategory
import SwiftUI

class CategoryViewModel: ObservableObject {
    @Published var categories: [AppCategory: [AppInfo]] = [:] // Maps categories to arrays of apps
    @Published var allApps: [AppInfo] = []
    @Published var selectedCategory: AppCategory? // Currently selected category
    @Published var selectedTechStack: TechStack? // Currently selected tech stack for filtering

    // Returns all categories, sorted alphabetically
    var sortedCategories: [AppCategory] {
        Array(categories.keys).sorted { $0.description < $1.description }
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

        // Always reset to show all apps with no specific category or tech stack selected after an update.
        selectedCategory = nil
        selectedTechStack = nil
    }

    // Select a specific category
    func selectCategory(_ category: AppCategory?) {
        selectedCategory = category
    }

    // Select a specific tech stack
    func selectTechStack(_ techStack: TechStack?) {
        selectedTechStack = techStack
    }

    // Get a count of apps in each category
    func count(for category: AppCategory) -> Int {
        categories[category]?.count ?? 0
    }

    // Get a count of apps for a specific tech stack in a category
    func count(for category: AppCategory, techStack: TechStack) -> Int {
        (categories[category] ?? []).filter { $0.techStacks.contains(techStack) }.count
    }
}
