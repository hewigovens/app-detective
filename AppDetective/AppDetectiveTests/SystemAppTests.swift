@testable import DetectiveCore
import Foundation
import Testing

// Expectations follow the macOS release CI runs on; update them when the runner image moves.
struct SystemAppTests {
    static let apps: [(path: String, stacks: TechStack)] = [
        ("/System/Applications/Calculator.app", .swiftUI),
        ("/System/Applications/TextEdit.app", [.appKit, .swift]),
        ("/System/Applications/Automator.app", [.appKit, .objectiveC]),
        ("/System/Applications/Stocks.app", .catalyst),
        ("/System/Applications/Maps.app", [.catalyst, .swiftUI]),
        ("/System/Applications/Utilities/Disk Utility.app", [.appKit, .objectiveC]),
        ("/System/Applications/Utilities/Terminal.app", [.appKit, .swift]),
    ]

    @Test("System apps resolve to the expected stacks", arguments: apps)
    func detectsSystemApp(_ app: (path: String, stacks: TechStack)) throws {
        try #require(FileManager.default.fileExists(atPath: app.path), "\(app.path) is not installed")

        let detection = DetectService().detect(URL(fileURLWithPath: app.path))
        #expect(detection.stacks == app.stacks, "\(app.path): \(detection.matches)")
        #expect(detection.possibleStacks.isEmpty, "\(app.path): \(detection.matches)")
    }
}
