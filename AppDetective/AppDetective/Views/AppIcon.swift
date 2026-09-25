import AppKit
import SwiftUI

struct AppIcon: View {
    let iconData: Data?

    var body: some View {
        if let iconData, let image = NSImage(data: iconData) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.tertiary)
        }
    }
}
