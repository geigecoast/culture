import SwiftUI
import ImageIO
import CryptoKit

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
        let task = Task<UIImage?, Never> {
            if let data = try? Data(contentsOf: file) {
                return Self.downsample(data, maxPixelSize: maxPixelSize)
            }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            try? data.write(to: file, options: .atomic)
            return Self.downsample(data, maxPixelSize: maxPixelSize)
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
