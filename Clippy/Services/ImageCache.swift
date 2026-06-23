import AppKit

final class ImageCache {
    static let shared = ImageCache()

    private let imageCache = NSCache<NSUUID, NSImage>()
    private let appIconCache = NSCache<NSString, NSImage>()

    private init() {
        imageCache.countLimit = 200
        appIconCache.countLimit = 50
    }

    func image(for item: ClipboardItem) -> NSImage? {
        if let cached = imageCache.object(forKey: item.id as NSUUID) {
            return cached
        }
        guard let fileName = item.imageFileName,
              let data = ImageStore.shared.data(for: fileName),
              let image = NSImage(data: data) else {
            return nil
        }
        imageCache.setObject(image, forKey: item.id as NSUUID)
        return image
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
}
