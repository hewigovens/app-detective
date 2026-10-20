@testable import DetectiveCore
import Foundation
import Testing

// Expectations follow the macOS release CI runs on; update them when the runner image moves.
struct SystemAppTests {
    typealias SystemApp = (path: String, traits: Set<DetectiveCore.Trait>)

    static let apps: [SystemApp] = [
        ("/System/Applications/Calculator.app", [.swiftUI, .swift]),
        ("/System/Applications/TextEdit.app", [.appKit, .swift]),
        ("/System/Applications/Automator.app", [.appKit, .objectiveC]),
        ("/System/Applications/Stocks.app", [.catalyst, .swift]),
        ("/System/Applications/Maps.app", [.catalyst, .swiftUI, .swift]),
        ("/System/Applications/Utilities/Disk Utility.app", [.appKit, .objectiveC]),
        ("/System/Applications/Utilities/Terminal.app", [.appKit, .swift]),
    ]

    @Test("System apps resolve to the expected traits", arguments: apps)
    func detectsSystemApp(_ app: SystemApp) throws {
        try #require(FileManager.default.fileExists(atPath: app.path), "\(app.path) is not installed")

        let detection = DetectService().detect(URL(fileURLWithPath: app.path))
        #expect(detection.traits == app.traits, "\(app.path): \(detection.matches)")
        #expect(detection.possibleTraits.isEmpty, "\(app.path): \(detection.matches)")
    }
}
