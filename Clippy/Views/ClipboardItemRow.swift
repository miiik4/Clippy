import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    var isSnippet: Bool = false
    var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                leadingIcon
                    .frame(width: 28, height: 28)

                // Content preview
                VStack(alignment: .leading, spacing: 1) {
                    if let title = item.title {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }
                    contentPreview
                }
                .foregroundStyle(isSelected ? .white : .primary)

                Spacer()

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .orange)
                        .rotationEffect(.degrees(45))
                }

                // Arrow hint for expandable items
                if isSelected && item.isExpandable {
                    badge(isExpanded ? "\u{2190} to collapse" : "\u{2192} to preview", opacity: 0.6, fill: 0.15)
                }

                // Shortcut badge (⌘1 – ⌘9)
                if index < 9 {
                    badge("⌘\(index + 1)", opacity: 0.8, fill: 0.2)
                }
            }

            if isExpanded {
                expandedPreview
                    .padding(.top, 8)
                    .padding(.leading, 38)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : .clear)
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isExpanded)
    }

    // MARK: - Pieces

    /// Snippet bookmark, source app icon, or a generic type icon.
    @ViewBuilder
    private var leadingIcon: some View {
        if isSnippet {
            symbolTile("bookmark.fill", color: .orange)
        } else if let appIcon = item.sourceAppIcon {
            Image(nsImage: appIcon)
                .resizable()
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            switch item.contentType {
            case .text: symbolTile("doc.text", color: .blue)
            case .image: symbolTile("photo.on.rectangle", color: .blue)
            case .file: symbolTile("doc", color: .blue)
            }
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.contentType {
        case .text:
            HStack(spacing: 6) {
                if let color = item.colorValue {
                    Circle()
                        .fill(Color(nsColor: color))
                        .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                        .frame(width: 14, height: 14)
                } else if item.linkURL != nil {
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : Color.accentColor)
                }
                Text(item.previewText)
                    .lineLimit(item.title == nil ? 2 : 1)
                    .font(.system(size: 13))
                    .underline(item.linkURL != nil && !isSelected, color: .accentColor.opacity(0.4))
            }

        case .image:
            ThumbnailView(item: item, maxPixelSize: ImageCache.rowThumbnailSize, maxHeight: 36)

        case .file:
            HStack(spacing: 6) {
                if let first = item.fileURLs?.first {
                    Image(nsImage: ImageCache.shared.fileIcon(for: first))
                        .resizable()
                        .frame(width: 18, height: 18)
                }
                Text(item.previewText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.system(size: 13))
            }
        }
    }

    @ViewBuilder
    private var expandedPreview: some View {
        switch item.contentType {
        case .image:
            ThumbnailView(item: item, maxPixelSize: ImageCache.previewSize, maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        case .text:
            ScrollView {
                Text(item.textContent ?? "")
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .foregroundStyle(isSelected ? .white : .primary)
        case .file:
            VStack(alignment: .leading, spacing: 2) {
                ForEach(item.fileURLs ?? [], id: \.self) { url in
                    Text(url.path)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
        }
    }

    private func symbolTile(_ systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.15))
            Image(systemName: systemName)
                .font(.system(size: 12))
                .foregroundStyle(color)
        }
    }

    private func badge(_ text: String, opacity: Double, fill: Double) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(isSelected ? .white.opacity(opacity) : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? .white.opacity(fill) : Color.secondary.opacity(0.12))
            )
    }
}

/// Shows a downscaled image, loading it off the main thread on first use.
struct ThumbnailView: View {
    let item: ClipboardItem
    let maxPixelSize: CGFloat
    let maxHeight: CGFloat
    @State private var loaded: NSImage?

    var body: some View {
        Group {
            if let image = loaded ?? ImageCache.shared.cachedThumbnail(for: item, maxPixelSize: maxPixelSize) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: maxHeight)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: maxHeight * 1.5, height: maxHeight)
            }
        }
        .task(id: item.id) {
            loaded = await ImageCache.shared.thumbnail(for: item, maxPixelSize: maxPixelSize)
        }
    }
}
