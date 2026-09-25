@testable import AppDetective
import Foundation
import Testing

struct ScanServiceTests {
    @Test("Finds nested apps, skips hidden items, and doesn't descend into bundles")
    func findsApps() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        for path in ["A.app/Contents/Helpers/Inner.app", "Utilities/B.app", ".Hidden.app", "Empty"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(path), withIntermediateDirectories: true)
        }

        let result = try ScanService().scanWithDiagnostics(folderURL: root)

        #expect(Set(result.appURLs.map(\.lastPathComponent)) == ["A.app", "B.app"])
        #expect(!result.hasSkippedDirectories)
    }

    @Test("Reports unreadable subfolders without failing")
    func reportsUnreadableFolders() throws {
        let root = try makeTempDirectory()
        let lockedURL = root.appendingPathComponent("Locked")
        try FileManager.default.createDirectory(at: lockedURL, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: lockedURL.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: lockedURL.path)
            try? FileManager.default.removeItem(at: root)
        }

        let result = try ScanService().scanWithDiagnostics(folderURL: root)

        #expect(result.skippedDirectoryURLs.map(\.lastPathComponent) == ["Locked"])
    }

    @Test("Throws for a path that is not a folder")
    func throwsForFile() throws {
        #expect(throws: ScanService.ScanError.self) {
            try ScanService().scanWithDiagnostics(folderURL: URL(fileURLWithPath: "/usr/bin/true"))
        }
    }
}
