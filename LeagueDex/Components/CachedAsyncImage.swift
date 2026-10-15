import SwiftUI
import CryptoKit
import ImageIO

/// UIKit images are retained only while useful for on-screen rendering.
@MainActor
private enum ImageMemoryCache {
    static let storage: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 48 * 1024 * 1024
        cache.countLimit = 150
        return cache
    }()
}

/// Disk access is actor-isolated so SwiftUI never performs synchronous image I/O.
/// Assets expire after 30 days; cache data is capped at 160 MiB.
private actor ImageDiskCache {
    static let shared = ImageDiskCache()
    private let directory: URL
    private var lastPrune = Date.distantPast
    private let lifetime: TimeInterval = 30 * 24 * 60 * 60
    private let maxBytes = 160 * 1024 * 1024

    init() {
        directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LeagueDexImages", isDirectory: true)
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest)
    }

    func cachedData(for url: URL) -> Data? {
        let file = fileURL(for: url)
        guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
              let modified = values.contentModificationDate,
              Date().timeIntervalSince(modified) < lifetime else {
            try? FileManager.default.removeItem(at: file)
            return nil
        }
        return try? Data(contentsOf: file)
    }

    func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: fileURL(for: url))
    }

    func save(_ data: Data, for url: URL) {
        guard data.count <= maxBytes else { return }
        let file = fileURL(for: url)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
        pruneIfNeeded()
    }

    private func pruneIfNeeded() {
        guard Date().timeIntervalSince(lastPrune) >= 3600 else { return }
        lastPrune = Date()

        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return }

        var retained: [(url: URL, size: Int, modified: Date)] = []
        var totalSize = 0
        let now = Date()
        for file in files {
            guard let value = try? file.resourceValues(forKeys: keys),
                  value.isRegularFile == true else { continue }
            let modified = value.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modified) > lifetime {
                try? FileManager.default.removeItem(at: file)
            } else {
                let size = value.fileSize ?? 0
                retained.append((file, size, modified))
                totalSize += size
            }
        }

        // Discard oldest assets first, never unrelated files outside our directory.
        for entry in retained.sorted(by: { $0.modified < $1.modified }) where totalSize > maxBytes {
            try? FileManager.default.removeItem(at: entry.url)
            totalSize -= entry.size
        }
    }
}

/// Thumbnail generation is independent of the view's MainActor.
private enum ImageDecoder {
    nonisolated static func thumbnail(from data: Data, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(100, maxPixel),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return cgImage
    }
}

/// Share the bytes between cards, detail heroes and skin previews, even when
/// they request different thumbnail sizes. Each caller owns only its subscription:
/// disappearing views must not cancel a download still needed by another view.
private actor ImageDataLoader {
    static let shared = ImageDataLoader()

    struct Payload: Sendable {
        let id = UUID()
        let data: Data
        let fromDisk: Bool
    }

    private struct Pending: Sendable {
        let id: UUID
        let task: Task<Payload, Error>
        let bypassesDisk: Bool
        var consumers: Set<UUID>
    }

    private struct Completed: Sendable {
        let payload: Payload
        let retainedAt: TimeInterval
    }

    private var pending: [URL: Pending] = [:]
    // Bridge the short interval between the last download subscriber returning
    // and thumbnail decoding/persistence finishing. Bytes are never held without
    // a bound, even when a view disappears before it can validate the download.
    private var completed: [URL: Completed] = [:]
    private var completedBytes = 0
    private let completedByteLimit = 8 * 1024 * 1024
    private let completedEntryLimit = 4 * 1024 * 1024
    private let completedCountLimit = 24
    private let completedLifetime: TimeInterval = 5

    func data(for url: URL, bypassDisk: Bool = false) async throws -> Payload {
        try Task.checkCancellation()
        pruneCompleted()
        if let result = completed[url] { return result.payload }
        let consumer = UUID()
        let operation: Pending

        if var existing = pending[url], !bypassDisk || existing.bypassesDisk {
            existing.consumers.insert(consumer)
            pending[url] = existing
            operation = existing
        } else {
            let task = Task {
                if !bypassDisk, let bytes = await ImageDiskCache.shared.cachedData(for: url) {
                    try Task.checkCancellation()
                    return Payload(data: bytes, fromDisk: true)
                }
                try Task.checkCancellation()
                let (bytes, response) = try await URLSession.shared.data(from: url)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return Payload(data: bytes, fromDisk: false)
            }
            operation = Pending(id: UUID(), task: task, bypassesDisk: bypassDisk, consumers: [consumer])
            pending[url] = operation
        }

        let operationID = operation.id

        return try await withTaskCancellationHandler {
            defer { release(url: url, operationID: operationID, consumer: consumer) }
            try Task.checkCancellation()
            let payload = try await operation.task.value
            try Task.checkCancellation()
            retainUntilValidated(payload, for: url)
            return payload
        } onCancel: {
            Task {
                await self.release(url: url, operationID: operationID, consumer: consumer)
            }
        }
    }

    func discardRetainedData(for url: URL, payloadID: UUID) {
        guard let result = completed[url], result.payload.id == payloadID else { return }
        completedBytes -= result.payload.data.count
        completed[url] = nil
    }

    private func retainUntilValidated(_ payload: Payload, for url: URL) {
        guard !payload.fromDisk, payload.data.count <= completedEntryLimit else { return }
        pruneCompleted()
        if completed[url]?.payload.id == payload.id { return }
        if let previous = completed[url] {
            discardRetainedData(for: url, payloadID: previous.payload.id)
        }
        while completedBytes + payload.data.count > completedByteLimit || completed.count >= completedCountLimit {
            guard let oldest = completed.min(by: { $0.value.retainedAt < $1.value.retainedAt }) else { break }
            discardRetainedData(for: oldest.key, payloadID: oldest.value.payload.id)
        }
        completed[url] = Completed(payload: payload, retainedAt: ProcessInfo.processInfo.systemUptime)
        completedBytes += payload.data.count
    }

    private func pruneCompleted() {
        let now = ProcessInfo.processInfo.systemUptime
        let expired = completed.filter { now - $0.value.retainedAt >= completedLifetime }
        for (url, result) in expired {
            discardRetainedData(for: url, payloadID: result.payload.id)
        }
    }

    private func release(url: URL, operationID: UUID, consumer: UUID) {
        guard var operation = pending[url], operation.id == operationID else { return }
        operation.consumers.remove(consumer)
        if operation.consumers.isEmpty {
            pending[url] = nil
            operation.task.cancel()
        } else {
            pending[url] = operation
        }
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    var maxDimension: CGFloat = 400

    @Environment(\.displayScale) private var displayScale
    @State private var uiImage: UIImage?
    @State private var imageKey: String?
    @State private var failedKey: String?
    @State private var loadID: UUID?

    private var pixelDimension: Int { max(100, Int(maxDimension * displayScale)) }
    private var requestKey: String { "\(url?.absoluteString ?? "")#\(pixelDimension)" }

    private var displayedImage: UIImage? {
        if imageKey == requestKey, let uiImage { return uiImage }
        // A reused or newly presented view can render a memory hit in its very
        // first frame. Starting a .task must never briefly erase a cached image.
        return ImageMemoryCache.storage.object(forKey: requestKey as NSString)
    }

    /// Render thumbnail sizes appropriate to the real card, icon or splash.
    func imageDimension(_ points: CGFloat) -> Self {
        var copy = self
        copy.maxDimension = max(points, 44)
        return copy
    }

    var body: some View {
        Group {
            if let uiImage = displayedImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
                    .accessibilityLabel(failedKey == requestKey ? "Image indisponible" : "Chargement de l'image")
            }
        }
        .task(id: requestKey) {
            await loadImage(url: url, pixel: pixelDimension, key: requestKey)
        }
    }

    private func loadImage(url: URL?, pixel: Int, key: String) async {
        guard !Task.isCancelled else { return }
        let currentLoad = UUID()
        loadID = currentLoad
        failedKey = nil
        guard let url else { failedKey = key; return }
        if let cached = ImageMemoryCache.storage.object(forKey: key as NSString) {
            uiImage = cached
            imageKey = key
            return
        }

        do {
            var payload = try await ImageDataLoader.shared.data(for: url)
            try Task.checkCancellation()
            var decodedImage = await decode(payload.data, pixel: pixel)
            try Task.checkCancellation()

            // A damaged/obsolete disk entry must recover during this request,
            // without requiring the user to leave and reopen the champion.
            if decodedImage == nil, payload.fromDisk {
                await ImageDiskCache.shared.remove(url)
                try Task.checkCancellation()
                payload = try await ImageDataLoader.shared.data(for: url, bypassDisk: true)
                try Task.checkCancellation()
                decodedImage = await decode(payload.data, pixel: pixel)
                try Task.checkCancellation()
            }
            guard let decodedImage else {
                await ImageDataLoader.shared.discardRetainedData(for: url, payloadID: payload.id)
                throw URLError(.cannotDecodeContentData)
            }

            // Construct the lightweight UIKit wrapper on MainActor after decoding.
            let image = UIImage(cgImage: decodedImage)

            // Only persist validated downloads. A corrupted file is never recached.
            guard !Task.isCancelled, loadID == currentLoad else { return }
            ImageMemoryCache.storage.setObject(
                image,
                forKey: key as NSString,
                cost: image.cgImage.map { $0.bytesPerRow * $0.height } ?? pixel * pixel * 4
            )
            uiImage = image
            imageKey = key
            // Show the decoded image immediately; disk persistence is never on
            // the critical path for its first visible frame.
            if !payload.fromDisk {
                await ImageDiskCache.shared.save(payload.data, for: url)
                await ImageDataLoader.shared.discardRetainedData(for: url, payloadID: payload.id)
            }
        } catch {
            guard !Task.isCancelled, loadID == currentLoad else { return }
            failedKey = key
        }
    }

    private func decode(_ data: Data, pixel: Int) async -> CGImage? {
        let task = Task.detached(priority: .utility) {
            guard !Task.isCancelled else { return nil as CGImage? }
            return ImageDecoder.thumbnail(from: data, maxPixel: pixel)
        }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
