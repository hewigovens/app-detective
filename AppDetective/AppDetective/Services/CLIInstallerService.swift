import Foundation

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

struct CLIInstallerService {
    static let toolName = "appdetective"

    static var installDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
    }

    static var installURL: URL {
        installDirectory.appendingPathComponent(toolName)
    }

    static var installPath: String { installURL.path }

    /// Returns the path to the CLI binary shipped inside the app bundle, if present.
    static func bundledBinaryURL() -> URL? {
        Bundle.main.url(forResource: toolName, withExtension: nil)
    }

    /// Returns true if `installPath` is a symlink pointing at the currently running app's bundled CLI.
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

    /// Returns true if `~/.local/bin` is already in the user's `PATH`.
    static func isOnPath() -> Bool {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let resolved = (installDirectory.path as NSString).standardizingPath
        return path.split(separator: ":").contains { ($0 as NSString).standardizingPath == resolved }
    }

    /// Creates a symlink at `~/.local/bin/appdetective` pointing at the bundled CLI.
    /// Refuses to replace an existing non-symlink file at the install path to avoid clobbering user data.
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

    /// Removes the symlink at `~/.local/bin/appdetective` if it exists.
    /// Refuses to remove a non-symlink at the install path.
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

    /// Returns the file type at `path` without following symlinks, or `nil` if nothing is there.
    private static func itemType(at path: String) -> FileAttributeType? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attrs[.type] as? FileAttributeType
    }
}
