#!/usr/bin/env swift

import Foundation

struct Config {
    var appcastPath: URL
    var zipPath: URL
    var version: String
    var shortVersion: String
    var downloadURL: String
    var minSystemVersion: String
    var notesFile: URL?
    var signature: String?
    var signatureSHA3: String?
}

enum ArgumentError: Error, CustomStringConvertible {
    case missingValue(String)
    case unknownFlag(String)
    case required(String)

    var description: String {
        switch self {
        case .missingValue(let flag):
            return "Missing value for \(flag)"
        case .unknownFlag(let flag):
            return "Unknown flag \(flag)"
        case .required(let flag):
            return "Missing required argument \(flag)"
        }
    }
}

func parseArguments() throws -> Config {
    let args = CommandLine.arguments.dropFirst()
    var iterator = args.makeIterator()

    var appcastPath: URL?
    var zipPath: URL?
    var version: String?
    var shortVersion: String?
    var downloadURL: String?
    var minSystemVersion = "13.0"
    var notesFile: URL?
    var signature: String?
    var signatureSHA3: String?

    while let arg = iterator.next() {
        switch arg {
        case "--appcast":
            guard let value = iterator.next() else { throw ArgumentError.missingValue(arg) }
            appcastPath = URL(fileURLWithPath: value)
        case "--zip":
            guard let value = iterator.next() else { throw ArgumentError.missingValue(arg) }
            zipPath = URL(fileURLWithPath: value)
        case "--version":
            guard let value = iterator.next() else { throw ArgumentError.missingValue(arg) }
            version = value
        case "--short-version":
            guard let value = iterator.next() else { throw ArgumentError.missingValue(arg) }
            shortVersion = value
        case "--download-url":
            guard let value = iterator.next() else { throw ArgumentError.missingValue(arg) }
            downloadURL = value
        case "--min-system-version":
            guard let value = iterator.next() else { throw ArgumentError.missingValue(arg) }
            minSystemVersion = value
        case "--notes-file":
            guard let value = iterator.next() else { throw ArgumentError.missingValue(arg) }
            notesFile = URL(fileURLWithPath: value)
        case "--signature":
            guard let value = iterator.next() else { throw ArgumentError.missingValue(arg) }
            signature = value
        case "--signature-sha3":
            guard let value = iterator.next() else { throw ArgumentError.missingValue(arg) }
            signatureSHA3 = value
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            if arg.hasPrefix("--") {
                throw ArgumentError.unknownFlag(arg)
            } else {
                throw ArgumentError.unknownFlag(arg)
            }
        }
    }

    guard let appcast = appcastPath else { throw ArgumentError.required("--appcast") }
    guard let zip = zipPath else { throw ArgumentError.required("--zip") }
    guard let version = version else { throw ArgumentError.required("--version") }
    guard let downloadURL = downloadURL else { throw ArgumentError.required("--download-url") }
    let shortVersionResolved = shortVersion ?? version

    return Config(
        appcastPath: appcast,
        zipPath: zip,
        version: version,
        shortVersion: shortVersionResolved,
        downloadURL: downloadURL,
        minSystemVersion: minSystemVersion,
        notesFile: notesFile,
        signature: signature,
        signatureSHA3: signatureSHA3
    )
}

func printUsage() {
    let usage = """
    Usage: generate_appcast.swift --appcast <path> --zip <path> --version <version> --download-url <url> [options]

    Options:
      --short-version <value>    Short version string (defaults to --version)
      --min-system-version <v>   Minimum macOS version (default 13.0)
      --notes-file <path>        Markdown/HTML file for release notes (optional)
      --signature <value>        Sparkle ed25519 signature (optional)
      --signature-sha3 <value>   Sparkle ed25519 SHA3 signature (optional)
    """
    print(usage)
}

func htmlEscaped(_ text: String) -> String {
    var result = text
    let entities: [(original: String, escaped: String)] = [
        ("&", "&amp;"),
        ("<", "&lt;"),
        (">", "&gt;"),
        ("\"", "&quot;"),
        ("'", "&#39;")
    ]
    for entity in entities {
        result = result.replacingOccurrences(of: entity.original, with: entity.escaped)
    }
    return result
}

func loadNotes(from url: URL?) -> String {
    guard let url, FileManager.default.fileExists(atPath: url.path) else {
        return "<p>Bug fixes and improvements.</p>"
    }
    do {
        let raw = try String(contentsOf: url, encoding: .utf8)
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "<p>Bug fixes and improvements.</p>"
        }
        let escaped = htmlEscaped(raw)
        return "<pre>\n\(escaped)\n</pre>"
    } catch {
        return "<p>Bug fixes and improvements.</p>"
    }
}

func rfc822Date(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
}

func fileSizeString(for url: URL) throws -> String {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    if let size = attributes[.size] as? NSNumber {
        return size.stringValue
    }
    throw NSError(domain: "generate_appcast", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to determine file size for \(url.path)"])
}

func ensureBaseAppcast(at url: URL, downloadURL: String) throws {
    if FileManager.default.fileExists(atPath: url.path) {
        return
    }

    let baseLink: String
    if let base = URL(string: downloadURL)?.deletingLastPathComponent().absoluteString {
        baseLink = base.hasSuffix("/") ? base + "appcast.xml" : base + "/appcast.xml"
    } else {
        baseLink = "https://hewig.dev/appdetective/appcast.xml"
    }

    let base = """
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<rss xmlns:sparkle=\"http://www.andymatuschak.org/xml-namespaces/sparkle\" version=\"2.0\">
  <channel>
    <title>App Detective Updates</title>
    <link>\(baseLink)</link>
    <description>Release notes and downloads for App Detective.</description>
    <language>en</language>
  </channel>
</rss>
"""
    try base.write(to: url, atomically: true, encoding: .utf8)
}

func generateItem(config: Config, fileSize: String, notes: String) -> String {
    let pubDate = rfc822Date(Date())
    var enclosureAttributes: [String] = [
        "url=\"\(config.downloadURL)\"",
        "sparkle:os=\"macos\"",
        "length=\"\(fileSize)\"",
        "type=\"application/octet-stream\""
    ]
    if let signature = config.signature {
        enclosureAttributes.append("sparkle:edSignature=\"\(signature)\"")
    }
    if let signatureSHA3 = config.signatureSHA3 {
        enclosureAttributes.append("sparkle:edSignature31=\"\(signatureSHA3)\"")
    }

    let enclosure = enclosureAttributes.joined(separator: "\n        ")

    return """
    <item>
      <title>App Detective \(config.shortVersion)</title>
      <description>
        <![CDATA[
        \(notes)
        ]]>
      </description>
      <pubDate>\(pubDate)</pubDate>
      <sparkle:version>\(config.version)</sparkle:version>
      <sparkle:shortVersionString>\(config.shortVersion)</sparkle:shortVersionString>
      <enclosure
        \(enclosure)
      />
      <sparkle:minimumSystemVersion>\(config.minSystemVersion)</sparkle:minimumSystemVersion>
    </item>
"""
}

func updateAppcast(at url: URL, with item: String) throws {
    let contents = try String(contentsOf: url, encoding: .utf8)
    guard let range = contents.range(of: "</channel>") else {
        throw NSError(domain: "generate_appcast", code: 2, userInfo: [NSLocalizedDescriptionKey: "Malformed appcast: missing </channel>"])
    }
    let before = contents[..<range.lowerBound]
    let after = contents[range.lowerBound...]
    let updated = before + item + "\n" + after
    try updated.write(to: url, atomically: true, encoding: .utf8)
}

func removeExistingItem(for version: String, in url: URL) throws {
    let contents = try String(contentsOf: url, encoding: .utf8)
    if contents.contains("<sparkle:version>\(version)</sparkle:version>") {
        let pattern = "\\s*<item>\\s*<title>App Detective .*?<sparkle:version>\(version)</sparkle:version>.*?</item>\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return
        }
        let range = NSRange(location: 0, length: (contents as NSString).length)
        let updated = regex.stringByReplacingMatches(in: contents, options: [], range: range, withTemplate: "")
        try updated.write(to: url, atomically: true, encoding: .utf8)
    }
}

func main() {
    do {
        let config = try parseArguments()

        guard FileManager.default.fileExists(atPath: config.zipPath.path) else {
            throw NSError(domain: "generate_appcast", code: 3, userInfo: [NSLocalizedDescriptionKey: "Zip file not found at \(config.zipPath.path)"])
        }

        try ensureBaseAppcast(at: config.appcastPath, downloadURL: config.downloadURL)
        try removeExistingItem(for: config.version, in: config.appcastPath)

        let size = try fileSizeString(for: config.zipPath)
        let notes = loadNotes(from: config.notesFile)
        let item = generateItem(config: config, fileSize: size, notes: notes)
        try updateAppcast(at: config.appcastPath, with: item)

        print("Updated appcast at \(config.appcastPath.path) with version \(config.version)")
    } catch let error as ArgumentError {
        fputs("Error: \(error)\n", stderr)
        printUsage()
        exit(1)
    } catch {
        fputs("Error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

main()
