import Foundation
import Testing

struct CLITests {
    @Test("--json --explain reports stacks and evidence")
    func jsonOutput() throws {
        // The unit tests are hosted by the app, which embeds the CLI in its resources.
        let cliURL = try #require(Bundle.main.url(forResource: "appdetective", withExtension: nil))
        let app = try FakeApp(frameworks: ["Electron Framework.framework"])
        defer { app.remove() }

        let process = Process()
        process.executableURL = cliURL
        process.arguments = ["--json", "--explain", app.url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        let output = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(output["stacks"] as? [String] == ["Electron"])
        let evidence = try #require(output["evidence"] as? [[String: String]])
        #expect(evidence.first?["match"] == "Electron Framework.framework")
    }

    @Test("Rejects a path that is not an app bundle")
    func rejectsNonBundle() throws {
        let cliURL = try #require(Bundle.main.url(forResource: "appdetective", withExtension: nil))
        let process = Process()
        process.executableURL = cliURL
        process.arguments = ["/usr/bin"]
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 2)
    }
}
