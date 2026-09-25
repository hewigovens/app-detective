import Foundation

enum ProcessRunner {
    /// Runs a command-line tool and captures its standard output.
    /// - Parameters:
    ///   - toolPath: Absolute path of the tool to launch.
    ///   - arguments: Arguments passed to the tool.
    ///   - timeout: Seconds to wait before the tool is terminated.
    /// - Returns: The tool's standard output, or `nil` if it failed to launch or timed out.
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

        // Drain the pipe concurrently so a full pipe buffer can never stall the child process.
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

/// Holds data written by the reader thread; the semaphore orders the write before the read.
private final class OutputCollector: @unchecked Sendable {
    var data = Data()
}
