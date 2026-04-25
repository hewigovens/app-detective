import Combine
import DetectiveCore
import SwiftUI

class MetadataLoaderService {
    var onMetadataItemLoaded:
        ((_ path: String, _ iconData: Data?, _ sizeString: String?) -> Void)?
    var onAllMetadataLoaded: (() -> Void)?

    private var loadQueue: [String] = []
    private let processingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.appdetective.metadataloader"
        queue.maxConcurrentOperationCount = 5
        queue.qualityOfService = .background
        return queue
    }()

    private var activeGroup: DispatchGroup?

    func enqueuePaths(_ paths: [String]) {
        loadQueue.append(contentsOf: paths)
        processQueue()
    }

    private func processQueue() {
        guard activeGroup == nil, !loadQueue.isEmpty else {
            if loadQueue.isEmpty && activeGroup == nil {
                onAllMetadataLoaded?()
            }
            return
        }

        let group = DispatchGroup()
        activeGroup = group

        while let path = getNextPath() {
            group.enter()
            processingQueue.addOperation { [weak self] in
                autoreleasepool {
                    guard let self = self else {
                        group.leave()
                        return
                    }
                    self.loadMetadata(for: path)
                }
                group.leave()
            }
        }

        group.notify(queue: DispatchQueue.main) { [weak self] in
            guard let self = self else { return }

            if self.activeGroup !== group { return }

            self.activeGroup = nil

            if self.loadQueue.isEmpty {
                self.onAllMetadataLoaded?()
            } else {
                self.processQueue()
            }
        }
    }

    private func getNextPath() -> String? {
        guard !loadQueue.isEmpty else { return nil }
        return loadQueue.removeFirst()
    }

    private func loadMetadata(for path: String) {
        autoreleasepool {
            let iconData = NSWorkspace.shared.icon(forFile: path)
                .tiffRepresentation
            let sizeInBytes = BundleMetrics.size(at: URL(fileURLWithPath: path))
            let sizeString = sizeInBytes.map(BundleMetrics.format(bytes:))

            var thumbnailData: Data?
            if let fullData = iconData, let fullImage = NSImage(data: fullData) {
                thumbnailData = self.createThumbnailData(from: fullImage)
            }

            let finalPath = path
            let finalThumbnailData = thumbnailData
            let finalSizeString = sizeString

            DispatchQueue.main.async { [weak self] in
                guard self != nil else { return }
                self?.onMetadataItemLoaded?(finalPath, finalThumbnailData, finalSizeString)
            }
        }
    }

    private func createThumbnailData(from image: NSImage, size: CGFloat = 64.0)
        -> Data?
    {
        let newSize = NSSize(width: size, height: size)
        let thumbnail = NSImage(size: newSize)

        thumbnail.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1.0)
        thumbnail.unlockFocus()
        return thumbnail.tiffRepresentation
    }

}
