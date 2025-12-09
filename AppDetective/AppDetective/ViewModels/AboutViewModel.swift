import Foundation
import Combine

class AboutViewModel: ObservableObject {
    @Published var versionString: String
    @Published var copyrightString: String
    @Published var githubLinkURL: URL

    init() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        self.versionString = "Version \(appVersion) (\(buildNumber))"

        self.copyrightString = "© 2025 \(Constants.AppName). All rights reserved."
        
        // This force unwrap is generally unsafe, but in this specific app, Constants.githubLink is a known valid URL.
        self.githubLinkURL = URL(string: Constants.githubLink)!
    }
}
