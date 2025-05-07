import Combine
import SwiftUI

// Service responsible for loading icon and size metadata in the background.
class MetadataLoaderService {
    // Callbacks for communication, to be set by the client (e.g., ContentViewModel)
    var onMetadataItemLoaded: ((_ path: String, _ iconData: Data?, _ sizeString: String?) -> Void)?
    var onAllMetadataLoaded: (() -> Void)?

    private var loadQueue: [String] = [] // Queue of app paths to process
    private let processingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.appdetective.metadataloader"
        queue.maxConcurrentOperationCount = 5
        queue.qualityOfService = .background
        return queue
    }()

    private var activeGroup: DispatchGroup? // To track completion of a batch

    // Add paths to the loading queue and start processing if not already running
    func enqueuePaths(_ paths: [String]) {
        print("[MetadataLoader] Enqueuing \(paths.count) paths.")
        loadQueue.append(contentsOf: paths)
        processQueue()
    }

    private func processQueue() {
        // Don't start a new batch if one is already running or queue is empty
        guard activeGroup == nil, !loadQueue.isEmpty else {
            if activeGroup != nil { print("[MetadataLoader] processQueue called, but batch already running (activeGroup is not nil).") }
            if loadQueue.isEmpty { print("[MetadataLoader] processQueue called, but queue is empty.") }
            // If queue is empty AND activeGroup is nil, it might mean we finished the last item of a previous batch
            // and onAllMetadataLoaded should have been called. Or it's an initial empty state.
            if loadQueue.isEmpty && activeGroup == nil {
                print("[MetadataLoader] processQueue: Queue empty and no active group. Ensuring onAllMetadataLoaded is called if necessary.")
                // This might be redundant if notify handles it, but as a safeguard:
                // Only call if we're not expecting a group notification.
                // However, this check is tricky. The notify block is the primary place.
            }
            return
        }

        print("[MetadataLoader] Starting new concurrent batch for up to \(loadQueue.count) items...")

        let group = DispatchGroup()
        activeGroup = group // Mark batch as active
        print("[MSvc] Batch Started. Group: \(group)")

        // Add all current items in the queue as operations
        var operationsScheduled = 0
        while let path = getNextPath() { // Consume paths from the queue
            operationsScheduled += 1
            group.enter()
            processingQueue.addOperation { [weak self] in
                // --- Autorelease Pool for each operation's work ---
                autoreleasepool {
                    // Check self validity within the operation block
                    guard let self = self else {
                        print("[MSvc] Op: self is nil for path \(path). Leaving group.")
                        group.leave()
                        return
                    }
                    self.loadMetadata(for: path)
                } // End autorelease pool
                // ---------------------------------------------
                // Leave the group when the operation finishes
                group.leave()
            }
        }
        print("[MSvc] Scheduled \(operationsScheduled) ops for batch.")

        // Notify on the main thread when ALL operations in this group are done
        group.notify(queue: DispatchQueue.main) { [weak self] in
            guard let self = self else { 
                print("[MSvc] Notify: self is nil.")
                return 
            }
            print("[MSvc] Notify: Group \(group) completed.")

            // Critical: Check if the activeGroup is the *same* group that is notifying.
            if self.activeGroup !== group {
                print("[MSvc] Notify: Stale notification from group \(group). Active: \(String(describing: self.activeGroup)). Ignoring.")
                return
            }

            print("[MSvc] Notify: activeGroup matches. Clearing.")
            self.activeGroup = nil // Mark batch as finished

            // Check if the queue is now empty
            if self.loadQueue.isEmpty {
                print("[MSvc] Notify: Queue empty. Calling onAllMetadataLoaded.")
                self.onAllMetadataLoaded?()
            } else {
                // If more items were added while processing, kick off a new batch
                print("[MSvc] Notify: Queue has \(self.loadQueue.count) items. Next batch.")
                self.processQueue()
            }
        }
    }

    // Needs to be thread-safe if accessed from multiple places, but currently only background queue calls it
    private func getNextPath() -> String? { // Simple non-thread-safe removal
        guard !loadQueue.isEmpty else { return nil }
        return loadQueue.removeFirst()
    }

    private func loadMetadata(for path: String) {
        // ** This entire function now runs synchronously on the processingQueue **

        // --- Step 2: Perform Loading Work (Synchronously on this background thread) ---
        autoreleasepool { // Keep autoreleasepool for the loading work itself
            let iconData = NSWorkspace.shared.icon(forFile: path).tiffRepresentation
            let sizeInBytes = getTotalBundleSize(atPath: path)
            let sizeString = sizeInBytes != nil ? formatSize(bytes: sizeInBytes!) : nil

            // Create a smaller thumbnail from the original icon data
            var thumbnailData: Data?
            if let fullData = iconData, let fullImage = NSImage(data: fullData) {
                thumbnailData = self.createThumbnailData(from: fullImage)
            }

            // --- Step 3: Invoke Callback with Loaded Data (Dispatch to MainActor) ---
            // Capture necessary data for the main thread dispatch
            let finalPath = path
            let finalThumbnailData = thumbnailData
            let finalSizeString = sizeString

            DispatchQueue.main.async { [weak self] in
                // Ensure self is still valid, though less critical here as we're not accessing much of self
                guard self != nil else { return }
                self?.onMetadataItemLoaded?(finalPath, finalThumbnailData, finalSizeString)
            }
        } // End autoreleasepool for loading work
    }

    // Helper to create thumbnail DATA
    private func createThumbnailData(from image: NSImage, size: CGFloat = 64.0) -> Data? {
        let newSize = NSSize(width: size, height: size)
        let thumbnail = NSImage(size: newSize)

        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .sourceOver,
                   fraction: 1.0)
        thumbnail.unlockFocus()

        // Return the TIFF data of the thumbnail
        return thumbnail.tiffRepresentation
    }

    // --- Size/Format Helpers (copied from AppListCell for now) ---

    private func getTotalBundleSize(atPath path: String) -> Int64? {
        let url = URL(fileURLWithPath: path)
        do {
            // Request both keys
            let resourceKeys: Set<URLResourceKey> = [.totalFileSizeKey, .totalFileAllocatedSizeKey]
            let resourceValues = try url.resourceValues(forKeys: resourceKeys)

            // Prioritize totalFileSize, fallback to totalFileAllocatedSize
            if let totalSize = resourceValues.totalFileSize {
                return Int64(totalSize)
            } else if let allocatedSize = resourceValues.totalFileAllocatedSize {
                return Int64(allocatedSize)
            } else {
                // Fallback to manual calculation
                return calculateDirectorySize(atPath: path)
            }
        } catch {
            // Also fallback to manual calculation on error
            return calculateDirectorySize(atPath: path)
        }
    }

    // Manual fallback for calculating directory/bundle size
    private func calculateDirectorySize(atPath path: String) -> Int64? {
        let url = URL(fileURLWithPath: path)
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [], errorHandler: { url, error -> Bool in
            print("[MetadataLoader] Enumerator error at \(url): \(error)")
            return true // Continue even if one file fails
        }) else {
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
                // Decide if you want to return nil here or just skip the file
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
