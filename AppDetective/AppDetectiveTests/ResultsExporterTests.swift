@testable import AppDetective
import Foundation
import Testing

struct ResultsExporterTests {
    private let app = AppInfo(
        name: "Say \"Hi\", World",
        path: "/Applications/Say.app",
        bundleId: nil,
        traits: [.electron, .python, .rust, .squirrel],
        possibleTraits: [.java],
        category: .utilities,
        size: "12 MB"
    )

    @Test("CSV quotes fields containing commas or quotes")
    func csv() throws {
        let text = try #require(String(data: ResultsExporter.csv([app]), encoding: .utf8))
        let lines = text.components(separatedBy: "\r\n")

        #expect(lines[0] == "Name,Path,Bundle ID,Version,Category,UI Frameworks,Languages,Renderers,Updaters,Possible Traits,Size")
        #expect(lines[1] == #""Say ""Hi"", World",/Applications/Say.app,,,Utilities,Electron; Python,Rust,,Squirrel,Java,12 MB"#)
    }

    @Test("JSON groups traits by kind and lists possible traits")
    func json() throws {
        let rows = try #require(JSONSerialization.jsonObject(with: ResultsExporter.json([app])) as? [[String: Any]])

        #expect(rows.first?["traits"] as? [String: [String]] == ["ui": ["Electron", "Python"], "language": ["Rust"], "updater": ["Squirrel"]])
        #expect(rows.first?["possibleTraits"] as? [String] == ["Java"])
        #expect(rows.first?["bundleId"] == nil)
    }
}
