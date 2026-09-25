import Foundation
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? Constants.BundleId

    static let app = Logger(subsystem: subsystem, category: "App")
    static let cache = Logger(subsystem: subsystem, category: "Cache")
}
