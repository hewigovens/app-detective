import Foundation
import Sparkle

final class UpdateService: NSObject, ObservableObject {
    @Published private(set) var isCheckingForUpdates: Bool = false
    @Published private(set) var lastUpdateError: String?

    private let isPreview: Bool
    private var didStart: Bool = false
    private var updaterController: SPUStandardUpdaterController?

    override init() {
        self.isPreview = false
        super.init()
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: self
        )
    }

    init(preview: Bool) {
        self.isPreview = preview
        super.init()
        guard !preview else {
            return
        }
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: self
        )
    }

    @MainActor
    func startIfNeeded() {
        guard !isPreview,
              !didStart,
              let updaterController,
              isFeedConfigured(reportError: false) else {
            return
        }

        updaterController.startUpdater()
        let updater = updaterController.updater
        updater.automaticallyChecksForUpdates = true
        updater.automaticallyDownloadsUpdates = false
        didStart = true
        updater.checkForUpdatesInBackground()
    }

    @MainActor
    func checkForUpdates() {
        guard !isPreview,
              let updaterController else {
            return
        }

        guard isFeedConfigured(reportError: true) else {
            isCheckingForUpdates = false
            return
        }

        startIfNeeded()

        guard !isCheckingForUpdates else {
            return
        }

        lastUpdateError = nil
        isCheckingForUpdates = true
        updaterController.checkForUpdates(nil)
    }

    private func isFeedConfigured(reportError: Bool) -> Bool {
        guard let feedString = Constants.updateFeedURL,
              !feedString.isEmpty else {
            if reportError {
                lastUpdateError = "Update feed URL is not configured."
            }
            return false
        }

        guard URL(string: feedString) != nil else {
            if reportError {
                lastUpdateError = "Invalid update feed URL."
            }
            return false
        }

        return true
    }

    private func resetCheckingState() {
        DispatchQueue.main.async {
            self.isCheckingForUpdates = false
        }
    }

    private func report(_ error: Error?) {
        guard let error else {
            return
        }

        DispatchQueue.main.async {
            self.lastUpdateError = error.localizedDescription
            self.isCheckingForUpdates = false
        }
    }
}

extension UpdateService: SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        guard let feedString = Constants.updateFeedURL,
              !feedString.isEmpty else {
            return nil
        }

        guard URL(string: feedString) != nil else {
            report(UpdateServiceError.invalidFeedURL)
            return nil
        }

        return feedString
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        resetCheckingState()
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        resetCheckingState()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        report(error)
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        if let error {
            report(error)
        } else {
            resetCheckingState()
        }
    }
}

extension UpdateService: SPUStandardUserDriverDelegate {
    func standardUserDriverWillHandleShowingUpdater(_ userDriver: SPUStandardUserDriver) {
        resetCheckingState()
    }

    func standardUserDriver(_ userDriver: SPUStandardUserDriver, showError error: Error) {
        report(error)
    }
}

private enum UpdateServiceError: LocalizedError {
    case invalidFeedURL

    var errorDescription: String? {
        switch self {
        case .invalidFeedURL:
            return "Invalid update feed URL."
        }
    }
}
