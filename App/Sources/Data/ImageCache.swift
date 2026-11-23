import SwiftUI
import ImageIO
import CryptoKit
import os

private let imageLog = Logger(subsystem: "com.geigecoast.culture", category: "images")

/// Memory + disk image cache with ImageIO downsampling so large museum images
/// never get decoded at full resolution on the main thread.
actor ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let directory: URL
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    init() {
        directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "Images", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.totalCostLimit = 80 * 1024 * 1024
    }

    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        let key = "\(url.absoluteString)#\(Int(maxPixelSize))" as NSString
        if let hit = memory.object(forKey: key) { return hit }
        if let task = inFlight[url] { return await task.value }

        let file = directory.appending(path: Self.fileName(for: url))
        let bundled = Self.bundledURL(for: url)
        let task = Task<UIImage?, Never> {
            // 1. Copy shipped inside the app (scripts/images/bundle_artwork.py): works offline.
            if let bundled, let data = try? Data(contentsOf: bundled) {
                return Self.downsample(data, maxPixelSize: maxPixelSize)
            }
            // 2. Disk cache from an earlier download.
            if let data = try? Data(contentsOf: file) {
                return Self.downsample(data, maxPixelSize: maxPixelSize)
            }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard status == 200 else {
                    imageLog.error("Image HTTP \(status, privacy: .public) for \(url.absoluteString, privacy: .public)")
                    return nil
                }
                guard let image = Self.downsample(data, maxPixelSize: maxPixelSize) else {
                    imageLog.error("Image decode failed (\(data.count, privacy: .public) bytes) for \(url.absoluteString, privacy: .public)")
                    return nil
                }
                try? data.write(to: file, options: .atomic)
                return image
            } catch {
                imageLog.error("Image load error \(error.localizedDescription, privacy: .public) for \(url.absoluteString, privacy: .public)")
                return nil
            }
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image {
            memory.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * image.scale * 4))
        }
        return image
    }

    func prefetch(_ urls: [URL], maxPixelSize: CGFloat) {
        for url in urls { Task { _ = await image(for: url, maxPixelSize: maxPixelSize) } }
    }

    private static func fileName(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Bundled artwork is named sha256(url).jpg, in an "Artwork" folder or at the bundle root.
    private static func bundledURL(for url: URL) -> URL? {
        let name = fileName(for: url)
        return Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "Artwork")
            ?? Bundle.main.url(forResource: name, withExtension: "jpg")
    }

    private static func downsample(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Lazily loads a cached, downsampled image with a placeholder.
struct CachedImage<Placeholder: View>: View {
    let url: URL?
    var maxPixelSize: CGFloat = 1200
    @ViewBuilder var placeholder: () -> Placeholder
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            image = await ImageCache.shared.image(for: url, maxPixelSize: maxPixelSize)
        }
    }
}
