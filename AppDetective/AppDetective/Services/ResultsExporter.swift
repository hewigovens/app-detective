import DetectiveCore
import Foundation

enum ResultsExporter {
    private struct Row: Encodable {
        let name: String
        let path: String
        let bundleId: String?
        let version: String?
        let category: String
        let traits: [String: [String]]
        let possibleTraits: [String]
        let size: String?

        init(_ app: AppInfo) {
            name = app.name
            path = app.path
            bundleId = app.bundleId
            version = app.version
            category = app.category.description
            traits = Trait.namesByKind(app.traits)
            possibleTraits = Trait.names(app.possibleTraits)
            size = app.size
        }
    }

    static func json(_ apps: [AppInfo]) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(apps.map(Row.init))) ?? Data()
    }

    static func csv(_ apps: [AppInfo]) -> Data {
        let header = ["Name", "Path", "Bundle ID", "Version", "Category"]
            + TraitKind.allCases.map(\.pluralName) + ["Possible Traits", "Size"]
        let rows = apps.map { app in
            [
                app.name,
                app.path,
                app.bundleId ?? "",
                app.version ?? "",
                app.category.description,
            ]
                + TraitKind.allCases.map { kind in Trait.names(app.traits.filter { $0.kind == kind }).joined(separator: "; ") }
                + [Trait.names(app.possibleTraits).joined(separator: "; "), app.size ?? ""]
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
