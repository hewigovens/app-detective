@testable import AppDetective
import DetectiveCore
import Foundation
import Testing

struct AppAnalyzerTests {
    private let detectService = DetectService()
    private let sentinelIcon = Data("cached-icon".utf8)

    private func cachedEntry(for app: FakeApp, fingerprint: Date?, version: String) -> CachedApp {
        CachedApp(
            fingerprint: fingerprint,
            detectorVersion: version,
            bundleId: "cached",
            stacks: .gtk,
            possibleStacks: [],
            evidence: [],
            category: .games,
            iconData: sentinelIcon,
            size: "1 KB"
        )
    }

    private func infoPlistDate(of app: FakeApp) throws -> Date? {
        try app.url.appendingPathComponent("Contents/Info.plist")
            .resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    @Test("Reuses the cached entry when the app and rules are unchanged")
    func reusesCache() throws {
        let app = try FakeApp()
        defer { app.remove() }
        let cached = cachedEntry(for: app, fingerprint: try infoPlistDate(of: app), version: detectService.version)

        let result = AppAnalyzer.analyze(app.url, cached: cached, detectService: detectService)

        #expect(result.stacks == .gtk)
        #expect(result.iconData == sentinelIcon)
    }

    @Test("Re-detects but keeps icon and size when only the rules changed")
    func redetectsOnNewRules() throws {
        let app = try FakeApp()
        defer { app.remove() }
        let cached = cachedEntry(for: app, fingerprint: try infoPlistDate(of: app), version: "old")

        let result = AppAnalyzer.analyze(app.url, cached: cached, detectService: detectService)

        #expect(result.stacks == .appKit)
        #expect(result.detectorVersion == detectService.version)
        #expect(result.iconData == sentinelIcon)
        #expect(result.size == "1 KB")
    }

    @Test("Reloads everything when the app was updated")
    func reloadsUpdatedApp() throws {
        let app = try FakeApp()
        defer { app.remove() }
        let cached = cachedEntry(for: app, fingerprint: .distantPast, version: detectService.version)

        let result = AppAnalyzer.analyze(app.url, cached: cached, detectService: detectService)

        #expect(result.stacks == .appKit)
        #expect(result.iconData != sentinelIcon)
        #expect(result.size != "1 KB")
    }
}
