import Foundation

struct FakeApp {
    let url: URL

    init(
        frameworks: [String] = [],
        resources: [String] = [],
        contents: [String] = [],
        declaresExecutable: Bool = true,
        category: String? = nil
    ) throws {
        let fileManager = FileManager.default
        let name = "Fake\(UUID().uuidString.prefix(8))"
        url = try makeTempDirectory().appendingPathComponent("\(name).app")

        let contentsURL = url.appendingPathComponent("Contents")
        let macOSURL = contentsURL.appendingPathComponent("MacOS")
        try fileManager.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        // A Mach-O that links only libSystem.
        try fileManager.copyItem(atPath: "/usr/bin/true", toPath: macOSURL.appendingPathComponent(name).path)

        var info: [String: Any] = ["CFBundleIdentifier": "test.\(name)", "CFBundlePackageType": "APPL"]
        if declaresExecutable {
            info["CFBundleExecutable"] = name
        }
        if let category {
            info["LSApplicationCategoryType"] = category
        }
        try writePlist(info, to: contentsURL.appendingPathComponent("Info.plist"))

        // Rules only check existence, so directories suffice.
        let items = frameworks.map { "Frameworks/\($0)" } + resources.map { "Resources/\($0)" } + contents
        for item in items {
            try fileManager.createDirectory(at: contentsURL.appendingPathComponent(item), withIntermediateDirectories: true)
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

func makeTempDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("AppDetectiveTests_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func writePlist(_ plist: [String: Any], to url: URL) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: url)
}
