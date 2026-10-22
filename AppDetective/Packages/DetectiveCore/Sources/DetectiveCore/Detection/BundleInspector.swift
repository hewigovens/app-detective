import Foundation
import Security

final class BundleInspector {
    private typealias Binary = (path: String, bytes: Data)

    // Referenced below, so it is in every binary that links DetectiveCore, whose catalog strings must not match.
    private static let catalogMarker = Data("DetectiveCore.BundleInspector.catalogMarker".utf8)

    let bundle: Bundle
    // Frameworks left out of code-string searches; set before the first one runs.
    var excludedFrameworks: Set<String> = []

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

    private lazy var executable: Binary? = executableURL.map(binary(at:))

    // The executable, the app's own frameworks and dylibs, and its app and system extensions.
    private lazy var codeBinaries: [Binary] = {
        let frameworkURLs = frameworks
            .filter { !excludedFrameworks.contains($0) }
            .compactMap { bundle.privateFrameworksURL?.appendingPathComponent($0) }
        let systemExtensionsURL = bundle.bundleURL.appendingPathComponent("Contents/Library/SystemExtensions")
        let bundleURLs = frameworkURLs.filter { $0.pathExtension == "framework" }
            + plugIns.filter { $0.hasSuffix(".appex") }.compactMap { bundle.builtInPlugInsURL?.appendingPathComponent($0) }
            + Self.itemNames(in: systemExtensionsURL).map { systemExtensionsURL.appendingPathComponent($0) }
        let urls = frameworkURLs.filter { $0.pathExtension == "dylib" } + bundleURLs.compactMap { Bundle(url: $0)?.executableURL }
        return [executable].compactMap { $0 } + urls.map(binary(at:))
    }()

    private lazy var signingInformation: [String: Any] = {
        // The executable, as iOS apps on Apple silicon are signed inside their wrapper.
        var code: SecStaticCode?
        var information: CFDictionary?
        guard
            SecStaticCodeCreateWithPath((executableURL ?? bundle.bundleURL) as CFURL, [], &code) == errSecSuccess,
            let code,
            SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation | kSecCSRequirementInformation), &information) == errSecSuccess
        else {
            return [:]
        }
        return information as? [String: Any] ?? [:]
    }()

    private lazy var signer: String? = {
        guard let leaf = (signingInformation[kSecCodeInfoCertificates as String] as? [SecCertificate])?.first else { return nil }
        return SecCertificateCopySubjectSummary(leaf) as String?
    }()

    private lazy var entitlements = signingInformation[kSecCodeInfoEntitlementsDict as String] as? [String: Any] ?? [:]

    private lazy var rootPath = bundle.bundleURL.resolvingSymlinksInPath().path + "/"
    private var catalogHosts: [String: Bool] = [:]

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
            firstBinary(containing: text, in: [executable].compactMap { $0 }).map { _ in text }
        case let .codeString(text):
            firstBinary(containing: text, in: codeBinaries)
        case let .signer(pattern):
            signer.flatMap { pattern.matches($0) ? $0 : nil }
        case let .signatureFlag(flag):
            hasSignatureFlag(flag) ? flag.rawValue : nil
        case let .entitlement(key):
            entitlements[key] as? Bool == true ? key : nil
        }
    }

    private func hasSignatureFlag(_ flag: SignatureFlag) -> Bool {
        let flags = SecCodeSignatureFlags(rawValue: signingInformation[kSecCodeInfoFlags as String] as? UInt32 ?? 0)
        return switch flag {
        case .adHoc: flags.contains(.adhoc)
        case .hardenedRuntime: flags.contains(.runtime)
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

    private func firstBinary(containing text: String, in binaries: [Binary]) -> String? {
        let needle = Data(text.utf8)
        for binary in binaries where Self.contains(needle, in: binary.bytes) && !isCatalogHost(binary) {
            return binary.path
        }
        return nil
    }

    // Checked only on a hit, as a miss already reads the whole binary and hits are rare.
    private func isCatalogHost(_ binary: Binary) -> Bool {
        if let cached = catalogHosts[binary.path] {
            return cached
        }
        let isHost = Self.contains(Self.catalogMarker, in: binary.bytes)
        catalogHosts[binary.path] = isHost
        return isHost
    }

    // Mapped rather than read, so only the pages a search touches are loaded.
    private func binary(at url: URL) -> Binary {
        let path = url.resolvingSymlinksInPath().path
        let bytes = (try? Data(contentsOf: url, options: .alwaysMapped)) ?? Data()
        return (path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : path, bytes)
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
}
