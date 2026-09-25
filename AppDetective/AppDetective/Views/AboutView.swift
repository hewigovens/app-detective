import SwiftUI

struct AboutView: View {
    @ObservedObject var updater: SparkleUpdater

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)

            VStack(spacing: 8) {
                Text(Constants.AppName)
                    .font(.title)
                    .fontWeight(.bold)

                Text(versionString)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Toggle("Check for updates automatically", isOn: $updater.autoChecksEnabled)

            Link("View on GitHub", destination: URL(string: Constants.githubLink)!)
                .buttonStyle(.link)

            Text("© 2025 \(Constants.AppName). All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(width: 350)
    }
}
