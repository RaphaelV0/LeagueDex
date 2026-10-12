import SwiftUI
import CryptoKit
import ImageIO

/// URL-keyed disk cache with a bounded in-memory cache.
private enum ImageCache {
    static let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 48 * 1024 * 1024
        cache.countLimit = 150
        return cache
    }()

    static func diskURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }.joined()
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("LeagueDexImages", isDirectory: true)
            .appendingPathComponent(digest)
    }

    static func decoded(_ data: Data, pointSize: CGFloat, scale: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let maxPixel = max(100, Int(pointSize * scale))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
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

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
                    .accessibilityLabel(failed ? "Image indisponible" : "Chargement de l'image")
            }
        }
        .task(id: url) {
            uiImage = nil
            failed = false
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else { failed = true; return }
        let key = "\(url.absoluteString)#\(Int(maxDimension * displayScale))" as NSString
        if let image = ImageCache.memory.object(forKey: key) {
            uiImage = image
            return
        }
        let path = ImageCache.diskURL(for: url)
        do {
            let data: Data
            if let cached = try? Data(contentsOf: path) {
                data = cached
            } else {
                let (download, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    failed = true
                    return
                }
                data = download
                let folder = path.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try? data.write(to: path, options: .atomic)
            }
            let image = ImageCache.decoded(data, pointSize: maxDimension, scale: displayScale)
            guard !Task.isCancelled else { return }
            guard let image else { failed = true; return }
            ImageCache.memory.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
            uiImage = image
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }
}
