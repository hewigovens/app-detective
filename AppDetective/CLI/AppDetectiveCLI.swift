import DetectiveCore
import Foundation
import LSAppCategory

@main
struct AppDetectiveCLI {
    struct Output: Encodable {
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

    static func main() async {
        var positional: [String] = []
        var jsonOutput = false
        var showHelp = false

        for arg in CommandLine.arguments.dropFirst() {
            switch arg {
            case "-h", "--help":
                showHelp = true
            case "--json":
                jsonOutput = true
            default:
                positional.append(arg)
            }
        }

        if showHelp {
            printUsage()
            exit(0)
        }
        guard positional.count == 1 else {
            printUsage()
            exit(1)
        }

        let url = URL(fileURLWithPath: (positional[0] as NSString).expandingTildeInPath).standardizedFileURL

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            emitError("not a directory: \(url.path)", json: jsonOutput)
            exit(2)
        }
        guard url.pathExtension.lowercased() == "app" else {
            emitError("expected a .app bundle, got: \(url.lastPathComponent)", json: jsonOutput)
            exit(2)
        }

        let service = DetectService()
        let stacks = await service.detectStack(for: url)
        let category = service.extractCategory(from: url)

        let bundle = Bundle(url: url)
        let bundleId = bundle?.bundleIdentifier
        let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let sizeBytes = bundleSize(at: url)
        let sizeHuman = sizeBytes.map(format(bytes:))

        let output = Output(
            name: url.lastPathComponent,
            path: url.path,
            bundleId: bundleId,
            version: version,
            build: build,
            sizeBytes: sizeBytes,
            sizeHuman: sizeHuman,
            category: category.description,
            stacks: stacks.displayNames
        )

        if jsonOutput {
            printJSON(output)
        } else {
            printText(output)
        }
    }

    static func printText(_ o: Output) {
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

    static func printJSON(_ o: Output) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            let data = try encoder.encode(o)
            try FileHandle.standardOutput.write(contentsOf: data)
            try FileHandle.standardOutput.write(contentsOf: Data("\n".utf8))
        } catch {
            emitError("failed to encode JSON: \(error.localizedDescription)", json: true)
            exit(3)
        }
    }

    static func emitError(_ message: String, json: Bool) {
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

    static func printUsage() {
        let name = (CommandLine.arguments.first.map { ($0 as NSString).lastPathComponent }) ?? "appdetective"
        print("Usage: \(name) [--json] <path-to-.app>")
        print("")
        print("Detect the tech stack and category of a single macOS app bundle.")
        print("")
        print("Options:")
        print("  --json        Emit machine-readable JSON instead of text.")
        print("  -h, --help    Show this help.")
    }

    /// Total on-disk size of an app bundle in bytes.
    static func bundleSize(at url: URL) -> Int64? {
        let keys: Set<URLResourceKey> = [.totalFileSizeKey, .totalFileAllocatedSizeKey]
        if let values = try? url.resourceValues(forKeys: keys) {
            if let total = values.totalFileSize { return Int64(total) }
            if let allocated = values.totalFileAllocatedSize { return Int64(allocated) }
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: []
        ) else {
            return nil
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    static func format(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
