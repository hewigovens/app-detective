@testable import AppDetective
import Foundation
import Testing

struct ResultsExporterTests {
    private let app = AppInfo(
        name: "Say \"Hi\", World",
        path: "/Applications/Say.app",
        bundleId: nil,
        techStacks: [.electron, .python],
        possibleStacks: .java,
        category: .utilities,
        size: "12 MB"
    )

    @Test("CSV quotes fields containing commas or quotes")
    func csv() throws {
        let text = try #require(String(data: ResultsExporter.csv([app]), encoding: .utf8))
        let lines = text.components(separatedBy: "\r\n")

        #expect(lines[0] == "Name,Path,Bundle ID,Category,Stacks,Possible Stacks,Size")
        #expect(lines[1] == #""Say ""Hi"", World",/Applications/Say.app,,Utilities,Electron; Python,Java,12 MB"#)
    }

    @Test("JSON includes stacks and possible stacks")
    func json() throws {
        let rows = try #require(JSONSerialization.jsonObject(with: ResultsExporter.json([app])) as? [[String: Any]])

        #expect(rows.first?["stacks"] as? [String] == ["Electron", "Python"])
        #expect(rows.first?["possibleStacks"] as? [String] == ["Java"])
        #expect(rows.first?["bundleId"] == nil)
    }
}
