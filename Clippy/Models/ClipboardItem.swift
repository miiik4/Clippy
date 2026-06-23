import Foundation
import AppKit

enum ClipboardContentType: Int, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let contentType: ClipboardContentType
    let textContent: String?
    let imageFileName: String?
    let timestamp: Date
    let sourceAppName: String?
    let sourceAppBundleID: String?

    init(
        id: UUID,
        contentType: ClipboardContentType,
        textContent: String?,
        imageFileName: String?,
        timestamp: Date,
        sourceAppName: String?,
        sourceAppBundleID: String?
    ) {
        self.id = id
        self.contentType = contentType
        self.textContent = textContent
        self.imageFileName = imageFileName
        self.timestamp = timestamp
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID
    }

    private enum CodingKeys: String, CodingKey {
        case id, contentType, textContent, textEncrypted, imageFileName, imageData, timestamp, sourceAppName, sourceAppBundleID
    }

    /// Custom decoder that migrates legacy entries which stored image bytes
    /// inline under `imageData` into standalone files via `ImageStore`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        contentType = try c.decode(ClipboardContentType.self, forKey: .contentType)
        timestamp = try c.decode(Date.self, forKey: .timestamp)

        let storedText = try c.decodeIfPresent(String.self, forKey: .textContent)
        let isEncrypted = try c.decodeIfPresent(Bool.self, forKey: .textEncrypted) ?? false
        if isEncrypted, let storedText {
            // Decrypt back to plaintext for in-memory use; nil if the key is gone.
            textContent = HistoryCrypto.shared.decrypt(storedText)
        } else {
            textContent = storedText
        }
        sourceAppName = try c.decodeIfPresent(String.self, forKey: .sourceAppName)
        sourceAppBundleID = try c.decodeIfPresent(String.self, forKey: .sourceAppBundleID)

        if let name = try c.decodeIfPresent(String.self, forKey: .imageFileName) {
            imageFileName = name
        } else if let legacy = try c.decodeIfPresent(Data.self, forKey: .imageData) {
            imageFileName = ImageStore.shared.write(legacy)
        } else {
            imageFileName = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(contentType, forKey: .contentType)

        // Encrypt text from sensitive apps so it is never written in plaintext.
        if let text = textContent {
            if isSensitive, let cipher = HistoryCrypto.shared.encrypt(text) {
                try c.encode(cipher, forKey: .textContent)
                try c.encode(true, forKey: .textEncrypted)
            } else {
                try c.encode(text, forKey: .textContent)
            }
        }

        try c.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sourceAppName, forKey: .sourceAppName)
        try c.encodeIfPresent(sourceAppBundleID, forKey: .sourceAppBundleID)
    }

    var isSensitive: Bool {
        guard let bundleID = sourceAppBundleID else { return false }
        return AppSettings.sensitiveAppBundleIDs.contains(bundleID)
    }

    var previewText: String {
        switch contentType {
        case .text:
            if isSensitive {
                return "\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}"
            }
            return textContent ?? ""
        case .image:
            return "Image"
        }
    }

    var image: NSImage? {
        ImageCache.shared.image(for: self)
    }

    var wordCount: Int {
        guard let text = textContent else { return 0 }
        return text.split(whereSeparator: { $0.isWhitespace }).count
    }

    var charCount: Int {
        return textContent?.count ?? 0
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var relativeTimeString: String {
        Self.relativeDateFormatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var sourceAppIcon: NSImage? {
        guard let bundleID = sourceAppBundleID else { return nil }
        return ImageCache.shared.appIcon(for: bundleID)
    }

    static func text(_ string: String, sourceApp: NSRunningApplication? = nil) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            contentType: .text,
            textContent: string,
            imageFileName: nil,
            timestamp: Date(),
            sourceAppName: sourceApp?.localizedName,
            sourceAppBundleID: sourceApp?.bundleIdentifier
        )
    }

    static func image(fileName: String, sourceAppName: String?, sourceAppBundleID: String?) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            contentType: .image,
            textContent: nil,
            imageFileName: fileName,
            timestamp: Date(),
            sourceAppName: sourceAppName,
            sourceAppBundleID: sourceAppBundleID
        )
    }
}
