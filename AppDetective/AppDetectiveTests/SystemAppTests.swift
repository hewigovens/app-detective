@testable import DetectiveCore
import Foundation
import Testing

// Expectations follow the macOS release CI runs on; update them when the runner image moves.
struct SystemAppTests {
    typealias SystemApp = (path: String, traits: Set<DetectiveCore.Trait>)

    static let apps: [SystemApp] = [
        ("/System/Applications/Calculator.app", [.swiftUI, .swift, .apple, .sandbox]),
        ("/System/Applications/TextEdit.app", [.appKit, .swift, .apple, .sandbox]),
        ("/System/Applications/Automator.app", [.appKit, .objectiveC, .apple, .hardenedRuntime]),
        ("/System/Applications/Stocks.app", [.catalyst, .swift, .apple, .sandbox]),
        ("/System/Applications/Maps.app", [.catalyst, .swiftUI, .swift, .apple, .sandbox]),
        ("/System/Applications/Utilities/Disk Utility.app", [.appKit, .objectiveC, .apple]),
        ("/System/Applications/Utilities/Terminal.app", [.appKit, .swift, .apple]),
    ]

    @Test("System apps resolve to the expected traits", arguments: apps)
    func detectsSystemApp(_ app: SystemApp) throws {
        try #require(FileManager.default.fileExists(atPath: app.path), "\(app.path) is not installed")

        let detection = DetectService().detect(URL(fileURLWithPath: app.path))
        #expect(detection.traits == app.traits, "\(app.path): \(detection.matches)")
        #expect(detection.possibleTraits.isEmpty, "\(app.path): \(detection.matches)")
    }
}
