import Foundation
import SwiftUI

// System category identifiers used in Info.plist files
enum AppCategoryConstants {
    static let developerTools = "public.app-category.developer-tools"
    static let utilities = "public.app-category.utilities"
    static let productivity = "public.app-category.productivity"
    static let reference = "public.app-category.reference"
    static let socialNetworking = "public.app-category.social-networking"
    static let education = "public.app-category.education"
    static let entertainment = "public.app-category.entertainment"
    static let games = "public.app-category.games"
    static let graphicsDesign = "public.app-category.graphics-design"
    static let healthFitness = "public.app-category.healthcare-fitness"
    static let lifestyle = "public.app-category.lifestyle"
    static let medical = "public.app-category.medical"
    static let music = "public.app-category.music"
    static let news = "public.app-category.news"
    static let photography = "public.app-category.photography"
    static let finance = "public.app-category.finance"
    static let business = "public.app-category.business"
    static let foodDrink = "public.app-category.food-drink"
    static let travel = "public.app-category.travel"
    static let sports = "public.app-category.sports"
    static let video = "public.app-category.video"
}

// Enum representing application categories
enum Category: String, CaseIterable, Identifiable, Hashable {
    case developerTools
    case utilities
    case productivity
    case reference
    case socialNetworking
    case education
    case entertainment
    case games
    case graphicsDesign
    case healthFitness
    case lifestyle
    case medical
    case music
    case news
    case photography
    case finance
    case business
    case foodDrink
    case travel
    case sports
    case video
    case uncategorized

    var id: String { self.rawValue }

    // Initialize from system category identifier
    init(fromSystemCategory systemCategory: String?) {
        guard let systemCategory = systemCategory else {
            self = .uncategorized
            return
        }

        switch systemCategory {
        case AppCategoryConstants.developerTools: self = .developerTools
        case AppCategoryConstants.utilities: self = .utilities
        case AppCategoryConstants.productivity: self = .productivity
        case AppCategoryConstants.reference: self = .reference
        case AppCategoryConstants.socialNetworking: self = .socialNetworking
        case AppCategoryConstants.education: self = .education
        case AppCategoryConstants.entertainment: self = .entertainment
        case AppCategoryConstants.games: self = .games
        case AppCategoryConstants.graphicsDesign: self = .graphicsDesign
        case AppCategoryConstants.healthFitness: self = .healthFitness
        case AppCategoryConstants.lifestyle: self = .lifestyle
        case AppCategoryConstants.medical: self = .medical
        case AppCategoryConstants.music: self = .music
        case AppCategoryConstants.news: self = .news
        case AppCategoryConstants.photography: self = .photography
        case AppCategoryConstants.finance: self = .finance
        case AppCategoryConstants.business: self = .business
        case AppCategoryConstants.foodDrink: self = .foodDrink
        case AppCategoryConstants.travel: self = .travel
        case AppCategoryConstants.sports: self = .sports
        case AppCategoryConstants.video: self = .video
        default: self = .uncategorized
        }
    }

    var displayName: String {
        switch self {
        case .developerTools: return "Developer Tools"
        case .utilities: return "Utilities"
        case .productivity: return "Productivity"
        case .reference: return "Reference"
        case .socialNetworking: return "Social Networking"
        case .education: return "Education"
        case .entertainment: return "Entertainment"
        case .games: return "Games"
        case .graphicsDesign: return "Graphics & Design"
        case .healthFitness: return "Health & Fitness"
        case .lifestyle: return "Lifestyle"
        case .medical: return "Medical"
        case .music: return "Music"
        case .news: return "News"
        case .photography: return "Photography"
        case .finance: return "Finance"
        case .business: return "Business"
        case .foodDrink: return "Food & Drink"
        case .travel: return "Travel"
        case .sports: return "Sports"
        case .video: return "Video"
        case .uncategorized: return "Uncategorized"
        }
    }
}

// Extension for category emoji representation
extension Category {
    var emoji: String {
        switch self {
        case .developerTools: return "🛠️"
        case .utilities: return "🔧"
        case .productivity: return "📊"
        case .reference: return "📚"
        case .socialNetworking: return "👥"
        case .education: return "🎓"
        case .entertainment: return "🎭"
        case .games: return "🎮"
        case .graphicsDesign: return "🎨"
        case .healthFitness: return "💪"
        case .lifestyle: return "🏡"
        case .medical: return "⚕️"
        case .music: return "🎵"
        case .news: return "📰"
        case .photography: return "📷"
        case .finance: return "💰"
        case .business: return "💼"
        case .foodDrink: return "🍽️"
        case .travel: return "✈️"
        case .sports: return "⚽"
        case .video: return "🎬"
        case .uncategorized: return "📁"
        }
    }
}
