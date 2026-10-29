import DetectiveCore
import Foundation
import LSAppCategory

@main
struct AppDetectiveCLI {
    static func main() {
        var positional: [String] = []
        var jsonOutput = false
        var explain = false
        var showHelp = false

        for arg in CommandLine.arguments.dropFirst() {
            switch arg {
            case "-h", "--help":
                showHelp = true
            case "--json":
                jsonOutput = true
            case "--explain":
                explain = true
            case let option where option.hasPrefix("-"):
                CLIPrinter.error("unknown option: \(option)", json: jsonOutput)
                exit(1)
            default:
                positional.append(arg)
            }
        }

        if showHelp {
            printUsage()
            exit(0)
        }
        guard positional.count == 1 else {
            printUsage(to: .standardError)
            exit(1)
        }

        let url = URL(fileURLWithPath: (positional[0] as NSString).expandingTildeInPath).standardizedFileURL

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            CLIPrinter.error("not a directory: \(url.path)", json: jsonOutput)
            exit(2)
        }
        guard url.pathExtension.lowercased() == "app" else {
            CLIPrinter.error("expected a .app bundle, got: \(url.lastPathComponent)", json: jsonOutput)
            exit(2)
        }

        let service = DetectService()
        let detection = service.detect(url)
        let category = service.extractCategory(from: url)

        let bundle = Bundle(url: url)
        let sizeBytes = BundleMetrics.size(at: url)

        let output = CLIOutput(
            name: url.lastPathComponent,
            path: url.path,
            bundleId: bundle?.bundleIdentifier,
            version: bundle?.shortVersion,
            build: bundle?.build,
            sizeBytes: sizeBytes,
            sizeHuman: sizeBytes.map(BundleMetrics.format(bytes:)),
            category: category.description,
            signer: detection.signer,
            traits: detection.traits.namesByKind,
            possibleTraits: detection.possibleTraits.names,
            evidence: explain ? detection.matches.map(CLIOutput.Evidence.init) : nil
        )

        if jsonOutput {
            CLIPrinter.json(output)
        } else {
            CLIPrinter.text(output)
        }
    }

    static func printUsage(to handle: FileHandle = .standardOutput) {
        let name = (CommandLine.arguments.first.map { ($0 as NSString).lastPathComponent }) ?? "appdetective"
        let usage = """
        Usage: \(name) [--json] [--explain] <path-to-.app>

        Detect the traits and category of a single macOS app bundle: its UI framework, language, renderer,
        graphics API, distribution, updater, security settings, and background items.

        Options:
          --json        Emit machine-readable JSON instead of text.
          --explain     Include the evidence behind each detected trait.
          -h, --help    Show this help.

        """
        try? handle.write(contentsOf: Data(usage.utf8))
    }
}
