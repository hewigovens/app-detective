import SwiftUI

struct AboutView: View {
    @StateObject private var viewModel = AboutViewModel()

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
                
                Text(viewModel.versionString)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Link("View on GitHub", destination: viewModel.githubLinkURL)
                .buttonStyle(.link)
            
            Text(viewModel.copyrightString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(width: 350)
    }
}

#Preview {
    AboutView()
}
