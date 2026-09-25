import Foundation

extension AppInfo {
    static let samples: [AppInfo] = [
        AppInfo(name: "Preview", path: "/System/Applications/Preview.app", bundleId: "com.apple.Preview", version: "11.0 (1053)", techStacks: .swiftUI, category: .utilities),
        AppInfo(name: "Xcode", path: "/Applications/Xcode.app", bundleId: "com.apple.dt.Xcode", techStacks: .appKit, category: .developerTools),
        AppInfo(name: "Safari", path: "/Applications/Safari.app", bundleId: "com.apple.Safari", techStacks: .appKit, category: .productivity),
        AppInfo(name: "Music", path: "/System/Applications/Music.app", bundleId: "com.apple.Music", techStacks: .catalyst, category: .music),
        AppInfo(name: "Slack", path: "/Applications/Slack.app", bundleId: "com.tinyspeck.slackmacgap", techStacks: .electron, category: .business),
    ]
}
