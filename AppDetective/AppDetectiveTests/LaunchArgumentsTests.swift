@testable import AppDetective
import Foundation
import Testing

struct LaunchArgumentsTests {
    private func folder(_ arguments: [String]) -> String? {
        LaunchArguments.startupFolderURL(from: ["AppDetective"] + arguments)?.path
    }

    @Test("Reads the folder from --scan-folder or a positional path")
    func readsFolder() {
        #expect(folder(["--scan-folder", "/Applications"]) == "/Applications")
        #expect(folder(["--scan-folder=/Applications"]) == "/Applications")
        #expect(folder(["/Applications"]) == "/Applications")
        #expect(folder([]) == nil)
    }

    @Test("Skips the values of user default arguments")
    func skipsDefaultValues() {
        #expect(folder(["-AppleLanguages", "(de)"]) == nil)
        #expect(folder(["-NSDocumentRevisionsDebugMode", "YES", "/Applications"]) == "/Applications")
        #expect(folder(["--verbose", "/Applications"]) == "/Applications")
    }
}
