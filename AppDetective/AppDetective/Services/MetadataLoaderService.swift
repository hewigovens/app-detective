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
        print("[MetadataLoader] Enqueuing \(paths.count) paths.")
        loadQueue.append(contentsOf: paths)
        processQueue()
    }

    private func processQueue() {
        guard activeGroup == nil, !loadQueue.isEmpty else {
            if activeGroup != nil {
                print("[MetadataLoader] processQueue called, but batch already running (activeGroup is not nil).")
            }
            if loadQueue.isEmpty {
                print("[MetadataLoader] processQueue called, but queue is empty.")
            }
            if loadQueue.isEmpty && activeGroup == nil {
                print("[MetadataLoader] processQueue: Queue empty and no active group. Ensuring onAllMetadataLoaded is called if necessary.")
                onAllMetadataLoaded?()
            }
            return
        }

        print("[MetadataLoader] Starting new concurrent batch for up to \(loadQueue.count) items...")

        let group = DispatchGroup()
        activeGroup = group
        print("[MSvc] Batch Started. Group: \(group)")

        var operationsScheduled = 0
        while let path = getNextPath() {
            operationsScheduled += 1
            group.enter()
            processingQueue.addOperation { [weak self] in
                autoreleasepool {
                    guard let self = self else {
                        print("[MSvc] Op: self is nil for path \(path). Leaving group.")
                        group.leave()
                        return
                    }
                    self.loadMetadata(for: path)
                }
                group.leave()
            }
        }
        print("[MSvc] Scheduled \(operationsScheduled) ops for batch.")

        group.notify(queue: DispatchQueue.main) { [weak self] in
            guard let self = self else {
                print("[MSvc] Notify: self is nil.")
                return
            }
            print("[MSvc] Notify: Group \(group) completed.")

            if self.activeGroup !== group {
                print("[MSvc] Notify: Stale notification from group \(group). Active: \(String(describing: self.activeGroup)). Ignoring.")
                return
            }

            self.activeGroup = nil

            if self.loadQueue.isEmpty {
                print("[MSvc] Notify: Queue empty. Calling onAllMetadataLoaded.")
                self.onAllMetadataLoaded?()
            } else {
                print(
                    "[MSvc] Notify: Queue has \(self.loadQueue.count) items. Next batch."
                )
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
        let url = URL(fileURLWithPath: path)
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
        let url = URL(fileURLWithPath: path)
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey],
            options: [],
            errorHandler: { url, error -> Bool in
                print("[MetadataLoader] Enumerator error at \(url): \(error)")
                return true
            })
        else {
            print("[MetadataLoader] Failed to create enumerator for \(path)")
            return nil
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            } catch {
                print("[MetadataLoader] Error getting size for file \(fileURL.path): \(error)")
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
