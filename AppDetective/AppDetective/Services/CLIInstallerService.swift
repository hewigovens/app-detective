import Foundation
import Darwin

enum CLIInstallerError: LocalizedError {
    case bundledBinaryMissing
    case installationFailed(String)

    var errorDescription: String? {
        switch self {
        case .bundledBinaryMissing:
            return "The bundled command-line tool could not be found inside the app."
        case .installationFailed(let message):
            return message
        }
    }
}

private actor CLIPathStatusCache {
    private var cachedValue: Bool?

    func value() -> Bool? {
        cachedValue
    }

    func setValue(_ value: Bool) {
        cachedValue = value
    }
}

struct CLIInstallerService {
    static let toolName = "appdetective"
    private static let pathStatusCache = CLIPathStatusCache()

    static var installDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
    }

    static var installURL: URL {
        installDirectory.appendingPathComponent(toolName)
    }

    static var installPath: String { installURL.path }

    static var pathHint: String {
        let shell = loginShell
        if shell.hasSuffix("fish") {
            return "fish_add_path \(installDirectory.path)"
        }

        let rcFile = if shell.hasSuffix("zsh") {
            "~/.zshrc"
        } else if shell.hasSuffix("bash") {
            "~/.bash_profile"
        } else {
            "~/.profile"
        }
        return "Add to \(rcFile):\nexport PATH=\"\(installDirectory.path):$PATH\""
    }

    static func bundledBinaryURL() -> URL? {
        Bundle.main.url(forResource: toolName, withExtension: nil)
    }

    static func isInstalled() -> Bool {
        guard let bundled = bundledBinaryURL() else { return false }
        let fm = FileManager.default
        guard fm.fileExists(atPath: installPath) else { return false }
        if let dest = try? fm.destinationOfSymbolicLink(atPath: installPath) {
            let resolved = (dest as NSString).standardizingPath
            return resolved == (bundled.path as NSString).standardizingPath
        }
        return false
    }

    static func isOnPath() async -> Bool {
        if let cachedValue = await pathStatusCache.value() {
            return cachedValue
        }

        let path = await loginShellPATH() ?? ProcessInfo.processInfo.environment["PATH"] ?? ""
        let isOnPath = pathContainsInstallDirectory(path)
        await pathStatusCache.setValue(isOnPath)
        return isOnPath
    }

    static func loginShellPATH() async -> String? {
        await Task.detached(priority: .userInitiated) {
            loginShellPATHSync()
        }.value
    }

    private static func loginShellPATHSync() -> String? {
        let shell = loginShell
        let isFish = shell.hasSuffix("fish")
        let command = isFish ? "string join : -- $PATH" : "printf %s \"$PATH\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-c", command]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")

        do {
            try process.run()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }

            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private static var loginShell: String {
        if let passwordEntry = getpwuid(getuid()),
           let shell = passwordEntry.pointee.pw_shell,
           let shellString = String(validatingCString: shell),
           !shellString.isEmpty
        {
            return shellString
        }

        return ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    private static func pathContainsInstallDirectory(_ path: String) -> Bool {
        let resolved = (installDirectory.path as NSString).standardizingPath
        return path.split(separator: ":").contains { ($0 as NSString).standardizingPath == resolved }
    }

    static func install() throws {
        guard let bundled = bundledBinaryURL() else {
            throw CLIInstallerError.bundledBinaryMissing
        }

        let fm = FileManager.default
        do {
            try fm.createDirectory(at: installDirectory, withIntermediateDirectories: true)
        } catch {
            throw CLIInstallerError.installationFailed(
                "Could not create \(installDirectory.path): \(error.localizedDescription)"
            )
        }

        if let existingType = itemType(at: installPath) {
            guard existingType == .typeSymbolicLink else {
                throw CLIInstallerError.installationFailed(
                    "A file already exists at \(installPath) and is not a symlink. Move or delete it manually and try again."
                )
            }
            do {
                try fm.removeItem(at: installURL)
            } catch {
                throw CLIInstallerError.installationFailed(
                    "Could not replace existing symlink at \(installPath): \(error.localizedDescription)"
                )
            }
        }

        do {
            try fm.createSymbolicLink(at: installURL, withDestinationURL: bundled)
        } catch {
            throw CLIInstallerError.installationFailed(
                "Could not create symlink: \(error.localizedDescription)"
            )
        }
    }

    static func uninstall() throws {
        let fm = FileManager.default
        guard let existingType = itemType(at: installPath) else { return }
        guard existingType == .typeSymbolicLink else {
            throw CLIInstallerError.installationFailed(
                "Refusing to remove \(installPath): it is not a symlink."
            )
        }
        do {
            try fm.removeItem(at: installURL)
        } catch {
            throw CLIInstallerError.installationFailed(
                "Could not remove \(installPath): \(error.localizedDescription)"
            )
        }
    }

    private static func itemType(at path: String) -> FileAttributeType? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attrs[.type] as? FileAttributeType
    }
}
