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

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    var maxDimension: CGFloat = 400

    @Environment(\.displayScale) private var displayScale
    @State private var uiImage: UIImage?
    @State private var failed = false

    /// Render thumbnail sizes appropriate to the real card, icon or splash.
    func imageDimension(_ points: CGFloat) -> Self {
        var copy = self
        copy.maxDimension = max(points, 44)
        return copy
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
                    .accessibilityLabel(failed ? "Image indisponible" : "Chargement de l'image")
            }
        }
        .task(id: "\(url?.absoluteString ?? "")#\(Int(maxDimension * displayScale))") {
            uiImage = nil
            failed = false
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else { failed = true; return }
        let pixel = max(100, Int(maxDimension * displayScale))
        let key = "\(url.absoluteString)#\(pixel)" as NSString
        if let cached = ImageMemoryCache.storage.object(forKey: key) {
            uiImage = cached
            return
        }

        do {
            let diskData = await ImageDiskCache.shared.cachedData(for: url)
            var data = diskData
            if data == nil {
                let (download, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode) else {
                    failed = true
                    return
                }
                data = download
            }
            guard let bytes = data, !Task.isCancelled else { return }
            let decodedImage = await Task.detached(priority: .utility) {
                ImageDecoder.thumbnail(from: bytes, maxPixel: pixel)
            }.value
            guard !Task.isCancelled else { return }
            guard let decodedImage else {
                await ImageDiskCache.shared.remove(url)
                failed = true
                return
            }

            // Construct the lightweight UIKit wrapper on MainActor after decoding.
            let image = UIImage(cgImage: decodedImage)

            // Only persist validated downloads. A corrupted file is never recached.
            if diskData == nil {
                await ImageDiskCache.shared.save(bytes, for: url)
            }
            guard !Task.isCancelled else { return }
            ImageMemoryCache.storage.setObject(
                image,
                forKey: key,
                cost: image.cgImage.map { $0.bytesPerRow * $0.height } ?? pixel * pixel * 4
            )
            uiImage = image
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }
}
