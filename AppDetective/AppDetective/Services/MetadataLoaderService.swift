import Combine
import SwiftUI // For NSImage, NSWorkspace

// Service responsible for loading icon and size metadata in the background.
@MainActor // Service itself operates on main actor for safe ViewModel interaction
class MetadataLoaderService {
    // Weak reference to avoid retain cycles if VM holds the service
    private weak var viewModel: ContentViewModel?

    private var loadQueue: [String] = [] // Queue of app paths to process
    private let processingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.appdetective.metadataloader"
        queue.maxConcurrentOperationCount = 5
        queue.qualityOfService = .background
        return queue
    }()

    private var activeGroup: DispatchGroup? // To track completion of a batch

    func setViewModel(_ viewModel: ContentViewModel) {
        self.viewModel = viewModel
    }

    // Add paths to the loading queue and start processing if not already running
    func enqueuePaths(_ paths: [String]) {
        print("[MetadataLoader] Enqueuing \(paths.count) paths.")
        loadQueue.append(contentsOf: paths)
        processQueue()
    }

    private func processQueue() {
        // Don't start a new batch if one is already running or queue is empty
        guard activeGroup == nil, !loadQueue.isEmpty else {
            if activeGroup != nil { print("[MetadataLoader] Batch already running.") }
            if loadQueue.isEmpty { print("[MetadataLoader] Queue empty.") }
            return
        }

        print("[MetadataLoader] Starting concurrent batch for up to \(loadQueue.count) items...")

        let group = DispatchGroup()
        activeGroup = group // Mark batch as active

        // Add all current items in the queue as operations
        while let path = getNextPath() { // Consume paths from the queue
            group.enter()
            processingQueue.addOperation { [weak self] in
                // --- Autorelease Pool for each operation's work ---
                autoreleasepool {
                    print("[MetadataLoader] Processing: \(path)")
                    // Check self validity within the operation block
                    guard let self = self else {
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

        // Notify on the main thread when ALL operations in this group are done
        group.notify(queue: DispatchQueue.main) { [weak self] in
            print("[MetadataLoader] Finished concurrent batch.")
            self?.activeGroup = nil // Mark batch as finished

            // If more items were added while processing, kick off a new batch
            if !(self?.loadQueue.isEmpty ?? true) {
                print("[MetadataLoader] New items added, starting next batch...")
                self?.processQueue()
            }
        }
    }

    // Needs to be thread-safe if accessed from multiple places, but currently only background queue calls it
    private func getNextPath() -> String? { // Simple non-thread-safe removal
        guard !loadQueue.isEmpty else { return nil }
        return loadQueue.removeFirst()
    }

    // Perform the actual loading (blocking work, called from background queue)
    private func loadMetadata(for path: String) {
        // ** This entire function now runs synchronously on the processingQueue **

        // --- Step 1: Check Cache (Requires brief sync jump to MainActor) ---
        var isCached = false
        let group = DispatchGroup()
        group.enter()
        Task { @MainActor [weak self] in
            guard let self = self, let viewModel = self.viewModel else {
                group.leave()
                return
            }
            if viewModel.getIconData(for: path) != nil, viewModel.getSizeString(for: path) != nil {
                // print("[MetadataLoader] Already cached: \(path)") // Optional: Reduce logging
                isCached = true
            }
            group.leave()
        }
        group.wait() // Wait for MainActor check to complete

        // If it was already cached, we're done for this path.
        guard !isCached else { return }

        // --- Step 2: Perform Loading Work (Synchronously on this background thread) ---
        autoreleasepool { // Keep autoreleasepool for the loading work itself
            print("[MetadataLoader] Loading data for: \(path)")
            let iconData = NSWorkspace.shared.icon(forFile: path).tiffRepresentation
            let size = self.getTotalBundleSize(atPath: path)
            let sizeString = (size != nil) ? self.formatSize(bytes: size!) : nil
            var thumbnailData: Data?
            if let fullData = iconData, let fullImage = NSImage(data: fullData) {
                thumbnailData = self.createThumbnailData(from: fullImage)
            }

            // --- Step 3: Update Cache (Dispatch ONLY this part back to MainActor) ---
            Task { @MainActor [weak self] in
                print("[MetadataLoader] Caching data for: \(path)")
                await self?.viewModel?.cacheData(path: path, iconData: thumbnailData, sizeString: sizeString)
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
                print("[MetadataLoader] Using totalFileSize for \(path): \(totalSize)")
                return Int64(totalSize)
            } else if let allocatedSize = resourceValues.totalFileAllocatedSize {
                print("[MetadataLoader] Using totalFileAllocatedSize for \(path): \(allocatedSize)")
                return Int64(allocatedSize)
            } else {
                print("[MetadataLoader] Both resource keys nil for \(path). Falling back to manual calculation.")
                // Fallback to manual calculation
                return calculateDirectorySize(atPath: path)
            }
        } catch {
            print("[MetadataLoader] Error getting resource values for \(path): \(error). Falling back to manual calculation.")
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
        print("[MetadataLoader] Manually calculated size for \(path): \(totalSize)")
        return totalSize
    }

    private func formatSize(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
