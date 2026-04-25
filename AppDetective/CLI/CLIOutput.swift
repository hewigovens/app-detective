import Foundation

/// Machine-readable shape of a single-app analysis result.
struct CLIOutput: Encodable {
    let name: String
    let path: String
    let bundleId: String?
    let version: String?
    let build: String?
    let sizeBytes: Int64?
    let sizeHuman: String?
    let category: String
    let stacks: [String]
}

enum CLIPrinter {
    static func text(_ o: CLIOutput) {
        let versionLine: String
        switch (o.version, o.build) {
        case let (v?, b?): versionLine = "\(v) (\(b))"
        case let (v?, nil): versionLine = v
        case let (nil, b?): versionLine = "(\(b))"
        default: versionLine = "—"
        }
        let stackLine = o.stacks.isEmpty ? "unknown" : o.stacks.joined(separator: ", ")
        print("App:        \(o.name)")
        print("Path:       \(o.path)")
        print("Bundle ID:  \(o.bundleId ?? "—")")
        print("Version:    \(versionLine)")
        print("Size:       \(o.sizeHuman ?? "—")")
        print("Category:   \(o.category)")
        print("Stacks:     \(stackLine)")
    }

    static func json(_ o: CLIOutput) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            let data = try encoder.encode(o)
            try FileHandle.standardOutput.write(contentsOf: data)
            try FileHandle.standardOutput.write(contentsOf: Data("\n".utf8))
        } catch {
            Self.error("failed to encode JSON: \(error.localizedDescription)", json: true)
            exit(3)
        }
    }

    static func error(_ message: String, json: Bool) {
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            if let data = try? encoder.encode(["error": message]) {
                try? FileHandle.standardError.write(contentsOf: data)
                try? FileHandle.standardError.write(contentsOf: Data("\n".utf8))
                return
            }
        }
        try? FileHandle.standardError.write(contentsOf: Data("error: \(message)\n".utf8))
    }
}
