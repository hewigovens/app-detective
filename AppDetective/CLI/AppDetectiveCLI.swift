import DetectiveCore
import Foundation
import LSAppCategory

@main
struct AppDetectiveCLI {
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
            CLIPrinter.error("not a directory: \(url.path)", json: jsonOutput)
            exit(2)
        }
        guard url.pathExtension.lowercased() == "app" else {
            CLIPrinter.error("expected a .app bundle, got: \(url.lastPathComponent)", json: jsonOutput)
            exit(2)
        }

        let service = DetectService()
        let stacks = await service.detectStack(for: url)
        let category = service.extractCategory(from: url)

        let bundle = Bundle(url: url)
        let sizeBytes = BundleMetrics.size(at: url)

        let output = CLIOutput(
            name: url.lastPathComponent,
            path: url.path,
            bundleId: bundle?.bundleIdentifier,
            version: bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            sizeBytes: sizeBytes,
            sizeHuman: sizeBytes.map(BundleMetrics.format(bytes:)),
            category: category.description,
            stacks: stacks.displayNames
        )

        if jsonOutput {
            CLIPrinter.json(output)
        } else {
            CLIPrinter.text(output)
        }
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
}
