import Foundation

extension AppInfo {
    static let samples: [AppInfo] = [
        AppInfo(name: "Preview", path: "/System/Applications/Preview.app", bundleId: "com.apple.Preview", version: "11.0 (1053)", traits: [.swiftUI, .swift], category: .utilities),
        AppInfo(name: "Xcode", path: "/Applications/Xcode.app", bundleId: "com.apple.dt.Xcode", traits: [.appKit, .swift], category: .developerTools),
        AppInfo(name: "Safari", path: "/Applications/Safari.app", bundleId: "com.apple.Safari", traits: [.appKit, .objectiveC], category: .productivity),
        AppInfo(name: "Music", path: "/System/Applications/Music.app", bundleId: "com.apple.Music", traits: [.catalyst, .swift], category: .music),
        AppInfo(name: "Slack", path: "/Applications/Slack.app", bundleId: "com.tinyspeck.slackmacgap", traits: [.electron], category: .business),
    ]
}
