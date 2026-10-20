import Foundation

final class BundleInspector {
    // Runtimes of other UI frameworks: their code (Chromium's Rust, for one) isn't the app's.
    private static let runtimeFrameworkMarkers = ["Electron", "Chromium", "Edge Framework"]
    // Referenced below, so it is in every binary that links DetectiveCore, whose catalog strings must not match.
    private static let catalogMarker = Data("DetectiveCore.BundleInspector.catalogMarker".utf8)

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
    private var entries: [String: [String]] = [:]

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

    private lazy var executableBytes: Data = executableURL.map(Self.binaryBytes(at:)) ?? Data()

    // The executable, the app's own frameworks and dylibs, and its app and system extensions.
    private lazy var codeBinaries: [(path: String, bytes: Data)] = {
        let contents = bundle.bundleURL.appendingPathComponent("Contents")
        var urls = executableURL.map { [$0] } ?? []
        for name in frameworks where !Self.runtimeFrameworkMarkers.contains(where: name.contains) {
            let url = contents.appendingPathComponent("Frameworks").appendingPathComponent(name)
            if name.hasSuffix(".dylib") {
                urls.append(url)
            } else if let executable = Bundle(url: url)?.executableURL {
                urls.append(executable)
            }
        }
        let extensionURLs = Self.itemURLs(in: bundle.builtInPlugInsURL, withExtension: "appex")
            + Self.itemURLs(in: contents.appendingPathComponent("Library/SystemExtensions"), withExtension: "systemextension")
        urls += extensionURLs.compactMap { Bundle(url: $0)?.executableURL }

        let root = bundle.bundleURL.resolvingSymlinksInPath().path + "/"
        return urls.map { url in
            let path = url.resolvingSymlinksInPath().path
            return (path.hasPrefix(root) ? String(path.dropFirst(root.count)) : path, Self.binaryBytes(at: url))
        }
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
        case let .entry(directory, pattern):
            entries(in: directory).first(where: pattern.matches)
        case let .embeddedString(text):
            Self.contains(text, in: executableBytes) ? text : nil
        case let .codeString(text):
            codeBinaries.first { Self.contains(text, in: $0.bytes) }?.path
        }
    }

    private func entries(in directory: String) -> [String] {
        if let cached = entries[directory] {
            return cached
        }
        let names = Self.itemNames(in: bundle.bundleURL.appendingPathComponent(directory))
        entries[directory] = names
        return names
    }

    // Mapped rather than read, so only the pages a search touches are loaded.
    private static func binaryBytes(at url: URL) -> Data {
        guard
            let bytes = try? Data(contentsOf: url, options: .alwaysMapped),
            !contains(catalogMarker, in: bytes)
        else {
            return Data()
        }
        return bytes
    }

    private static func contains(_ text: String, in bytes: Data) -> Bool {
        contains(Data(text.utf8), in: bytes)
    }

    // memmem, as Data.range(of:) and String.contains take seconds on executables of hundreds of megabytes.
    private static func contains(_ needle: Data, in bytes: Data) -> Bool {
        guard !needle.isEmpty, bytes.count >= needle.count else { return false }
        return bytes.withUnsafeBytes { haystack in
            needle.withUnsafeBytes { pattern in
                memmem(haystack.baseAddress, haystack.count, pattern.baseAddress, pattern.count) != nil
            }
        }
    }

    private static func itemNames(in directoryURL: URL?) -> [String] {
        guard let directoryURL else { return [] }
        return (try? FileManager.default.contentsOfDirectory(atPath: directoryURL.path)) ?? []
    }

    private static func itemURLs(in directoryURL: URL?, withExtension pathExtension: String) -> [URL] {
        guard let directoryURL else { return [] }
        return itemNames(in: directoryURL)
            .filter { $0.hasSuffix(".\(pathExtension)") }
            .map { directoryURL.appendingPathComponent($0) }
    }
}
