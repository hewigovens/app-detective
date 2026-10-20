import Foundation

enum ProcessRunner {
    static func output(of toolPath: String, arguments: [String], timeout: TimeInterval = 10) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        // Drain concurrently so a full pipe buffer can't stall the child.
        let collector = OutputCollector()
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            collector.data = stdout.fileHandleForReading.readDataToEndOfFile()
            finished.signal()
        }

        guard finished.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            finished.wait()
            return nil
        }
        process.waitUntilExit()
        return String(decoding: collector.data, as: UTF8.self)
    }
}

private final class OutputCollector: @unchecked Sendable {
    var data = Data()
}
