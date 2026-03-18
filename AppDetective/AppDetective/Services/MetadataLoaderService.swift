import Combine
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
            let sizeInBytes = getTotalBundleSize(atPath: path)
            let sizeString =
                sizeInBytes != nil ? formatSize(bytes: sizeInBytes!) : nil

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

    private func getTotalBundleSize(atPath path: String) -> Int64? {
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        do {
            let resourceKeys: Set<URLResourceKey> = [
                .totalFileSizeKey, .totalFileAllocatedSizeKey,
            ]
            let resourceValues = try url.resourceValues(forKeys: resourceKeys)

            if let totalSize = resourceValues.totalFileSize {
                return Int64(totalSize)
            } else if let allocatedSize = resourceValues.totalFileAllocatedSize {
                return Int64(allocatedSize)
            } else {
                return calculateDirectorySize(atPath: path)
            }
        } catch {
            return calculateDirectorySize(atPath: path)
        }
    }

    private func calculateDirectorySize(atPath path: String) -> Int64? {
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey],
            options: [],
            errorHandler: { _, error -> Bool in
                print("[MetadataLoader] Enumerator error: \(error)")
                return true
            })
        else {
            return nil
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            } catch {
                print("[MetadataLoader] Error getting size for \(fileURL.path): \(error)")
            }
        }
        return totalSize
    }

    private func formatSize(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
