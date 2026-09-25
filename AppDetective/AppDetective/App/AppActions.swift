import AppKit
import SwiftUI

@MainActor
enum AppActions {
    static func installCLI() async {
        let isOnPath = await CLIInstallerService.isOnPath()
        let alert = NSAlert()
        let wasInstalled = CLIInstallerService.isInstalled()
        if wasInstalled {
            alert.messageText = "Command Line Tool Already Installed"
            alert.informativeText = if isOnPath {
                "`appdetective` is already available at \(CLIInstallerService.installPath). Reinstall to update the symlink, or remove it."
            } else {
                "`appdetective` is linked at \(CLIInstallerService.installPath), but the directory is not in your PATH.\n\n\(CLIInstallerService.pathHint)"
            }
            alert.addButton(withTitle: "Reinstall")
            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Cancel")
        } else {
            alert.messageText = "Install Command Line Tool"
            alert.informativeText = "This will create a symlink at \(CLIInstallerService.installPath) so you can run `appdetective <path-to-.app>` from your terminal."
            alert.addButton(withTitle: "Install")
            alert.addButton(withTitle: "Cancel")
        }

        switch (wasInstalled, alert.runModal()) {
        case (true, .alertFirstButtonReturn), (false, .alertFirstButtonReturn):
            performInstall(isOnPath: isOnPath)
        case (true, .alertSecondButtonReturn):
            performUninstall()
        default:
            return
        }
    }

    private static func performInstall(isOnPath: Bool) {
        do {
            try CLIInstallerService.install()
            let alert = NSAlert()
            alert.messageText = "Command Line Tool Installed"
            var message = "`appdetective` is linked at \(CLIInstallerService.installPath)."
            if !isOnPath {
                message += "\n\nThe directory is not in your PATH.\n\n\(CLIInstallerService.pathHint)"
            }
            alert.informativeText = message
            alert.runModal()
        } catch {
            showErrorAlert(title: "Installation Failed", message: error.localizedDescription)
        }
    }

    private static func performUninstall() {
        do {
            try CLIInstallerService.uninstall()
            let alert = NSAlert()
            alert.messageText = "Command Line Tool Removed"
            alert.informativeText = "Removed \(CLIInstallerService.installPath)."
            alert.runModal()
        } catch {
            showErrorAlert(title: "Removal Failed", message: error.localizedDescription)
        }
    }

    private static func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private static var aboutWindowController: NSWindowController?

    static func showAboutWindow(updater: SparkleUpdater) {
        if aboutWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 350, height: 300),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            window.center()
            window.title = "About"
            window.contentView = NSHostingView(rootView: AboutView(updater: updater))
            aboutWindowController = NSWindowController(window: window)
        }

        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
    }
}
