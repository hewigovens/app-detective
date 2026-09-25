import Foundation

final class BundleInspector {
    let bundle: Bundle

    init(bundle: Bundle) {
        self.bundle = bundle
    }

    var executableURL: URL? {
        bundle.executableURL
    }

    private lazy var frameworks = Self.itemNames(in: bundle.privateFrameworksURL)
    private lazy var resources = Self.itemNames(in: bundle.resourceURL)
    private lazy var plugIns = Self.itemNames(in: bundle.builtInPlugInsURL)

    private lazy var linkedLibraries: [String] = {
        guard
            let executableURL,
            let output = ProcessRunner.output(of: "/usr/bin/otool", arguments: ["-L", executableURL.path])
        else {
            return []
        }
        // Untabbed lines name the binary itself, which would match apps by their own names.
        return output
            .split(separator: "\n")
            .filter { $0.hasPrefix("\t") }
            .map { line in
                let installName = line.dropFirst().components(separatedBy: " (compatibility version").first ?? ""
                return installName.trimmingCharacters(in: .whitespaces)
            }
    }()

    private lazy var embeddedStrings: String = {
        guard let executableURL else { return "" }
        return ProcessRunner.output(of: "/usr/bin/strings", arguments: [executableURL.path]) ?? ""
    }()

    func match(_ evidence: Evidence) -> String? {
        switch evidence {
        case let .framework(pattern):
            frameworks.first(where: pattern.matches)
        case let .resource(pattern):
            resources.first(where: pattern.matches)
        case let .plugIn(pattern):
            plugIns.first(where: pattern.matches)
        case let .file(path):
            FileManager.default.fileExists(atPath: bundle.bundleURL.appendingPathComponent(path).path) ? path : nil
        case let .linkedLibrary(pattern):
            linkedLibraries.first(where: pattern.matches)
        case let .embeddedString(text):
            embeddedStrings.contains(text) ? text : nil
        }
    }

    private static func itemNames(in directoryURL: URL?) -> [String] {
        guard let directoryURL else { return [] }
        return (try? FileManager.default.contentsOfDirectory(atPath: directoryURL.path)) ?? []
    }
}
