import Foundation

enum LaunchArguments {
    static let scanFolder = "--scan-folder"

    static var startupFolderURL: URL? {
        startupFolderURL(from: ProcessInfo.processInfo.arguments)
    }

    static func startupFolderURL(from arguments: [String]) -> URL? {
        if let flaggedPath = pathValue(for: scanFolder, in: arguments) {
            return folderURL(from: flaggedPath)
        }

        return positionalPath(in: arguments).map(folderURL)
    }

    private static func pathValue(for option: String, in arguments: [String]) -> String? {
        if let inlineArgument = arguments.first(where: { $0.hasPrefix("\(option)=") }) {
            let value = String(inlineArgument.dropFirst(option.count + 1))
            return validPathValue(value)
        }

        guard
            let argumentIndex = arguments.firstIndex(of: option),
            arguments.indices.contains(argumentIndex + 1)
        else {
            return nil
        }

        return validPathValue(arguments[argumentIndex + 1])
    }

    private static func validPathValue(_ value: String) -> String? {
        guard !value.isEmpty, !value.hasPrefix("-") else {
            return nil
        }

        return value
    }

    private static func positionalPath(in arguments: [String]) -> String? {
        var shouldSkipNextArgument = false

        for argument in arguments.dropFirst() {
            if shouldSkipNextArgument {
                shouldSkipNextArgument = false
                continue
            }

            // A single-dash `-Key value` pair sets a user default, such as -AppleLanguages "(de)".
            if argument == scanFolder || (argument.hasPrefix("-") && !argument.hasPrefix("--")) {
                shouldSkipNextArgument = true
                continue
            }

            if argument.hasPrefix("-") {
                continue
            }

            return argument
        }

        return nil
    }

    private static func folderURL(from path: String) -> URL {
        URL(
            fileURLWithPath: (path as NSString).expandingTildeInPath,
            isDirectory: true
        )
    }
}
