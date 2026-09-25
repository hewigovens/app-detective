import DetectiveCore
import Foundation

enum ResultsExporter {
    private struct Row: Encodable {
        let name: String
        let path: String
        let bundleId: String?
        let category: String
        let stacks: [String]
        let possibleStacks: [String]
        let size: String?

        init(_ app: AppInfo) {
            name = app.name
            path = app.path
            bundleId = app.bundleId
            category = app.category.description
            stacks = app.techStacks.displayNames
            possibleStacks = app.possibleStacks.displayNames
            size = app.size
        }
    }

    static func json(_ apps: [AppInfo]) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(apps.map(Row.init))) ?? Data()
    }

    static func csv(_ apps: [AppInfo]) -> Data {
        let header = ["Name", "Path", "Bundle ID", "Category", "Stacks", "Possible Stacks", "Size"]
        let rows = apps.map(Row.init).map { row in
            [
                row.name,
                row.path,
                row.bundleId ?? "",
                row.category,
                row.stacks.joined(separator: "; "),
                row.possibleStacks.joined(separator: "; "),
                row.size ?? "",
            ]
        }
        let lines = ([header] + rows).map { $0.map(escape).joined(separator: ",") }
        return Data((lines.joined(separator: "\r\n") + "\r\n").utf8)
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else {
            return field
        }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
