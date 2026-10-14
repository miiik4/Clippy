import AppKit
import ImageIO

final class ImageCache {
    static let shared = ImageCache()

    /// Pixel sizes for the two places images are shown.
    static let rowThumbnailSize: CGFloat = 96
    static let previewSize: CGFloat = 1200

    private let thumbnailCache = NSCache<NSString, NSImage>()
    private let appIconCache = NSCache<NSString, NSImage>()
    private let fileIconCache = NSCache<NSString, NSImage>()

    private init() {
        thumbnailCache.countLimit = 300
        appIconCache.countLimit = 50
        fileIconCache.countLimit = 100
    }

    /// Full-size image, decoded on demand and not cached.
    func image(for item: ClipboardItem) -> NSImage? {
        guard let fileName = item.imageFileName,
              let data = ImageStore.shared.data(for: fileName) else { return nil }
        return NSImage(data: data)
    }

    /// A downscaled thumbnail if already cached; never touches the disk.
    func cachedThumbnail(for item: ClipboardItem, maxPixelSize: CGFloat) -> NSImage? {
        thumbnailCache.object(forKey: Self.key(item, maxPixelSize))
    }

    /// Loads (off the main thread) and caches a downscaled thumbnail.
    func thumbnail(for item: ClipboardItem, maxPixelSize: CGFloat) async -> NSImage? {
        if let cached = cachedThumbnail(for: item, maxPixelSize: maxPixelSize) { return cached }
        guard let fileName = item.imageFileName else { return nil }
        let url = ImageStore.shared.url(for: fileName)
        let image = await Task.detached(priority: .userInitiated) {
            Self.makeThumbnail(at: url, maxPixelSize: maxPixelSize)
        }.value
        if let image {
            thumbnailCache.setObject(image, forKey: Self.key(item, maxPixelSize))
        }
        return image
    }

    private static func key(_ item: ClipboardItem, _ size: CGFloat) -> NSString {
        "\(item.id.uuidString)-\(Int(size))" as NSString
    }

    private nonisolated static func makeThumbnail(at url: URL, maxPixelSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        // Report size in points (2x) so SwiftUI does not upscale small images.
        let size = NSSize(width: CGFloat(cgImage.width) / 2, height: CGFloat(cgImage.height) / 2)
        return NSImage(cgImage: cgImage, size: size)
    }

    func appIcon(for bundleID: String) -> NSImage? {
        let key = bundleID as NSString
        if let cached = appIconCache.object(forKey: key) {
            return cached
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        appIconCache.setObject(icon, forKey: key)
        return icon
    }

    func fileIcon(for url: URL) -> NSImage {
        let key = url.path as NSString
        if let cached = fileIconCache.object(forKey: key) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        fileIconCache.setObject(icon, forKey: key)
        return icon
    }
}
