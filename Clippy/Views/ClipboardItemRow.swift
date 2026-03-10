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
                // Icon: source app icon, or fallback generic icon
                Group {
                    if isSnippet {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.orange.opacity(0.15))
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                        }
                    } else if let appIcon = item.sourceAppIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.blue.opacity(0.15))
                            Image(systemName: item.contentType == .text ? "doc.text" : "photo.on.rectangle")
                                .font(.system(size: 12))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .frame(width: 28, height: 28)

                // Content preview
                Group {
                    switch item.contentType {
                    case .text:
                        Text(item.previewText)
                            .lineLimit(2)
                            .font(.system(size: 13))

                    case .image:
                        if let nsImage = item.image {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 36)
                        } else {
                            Text("Image")
                                .font(.system(size: 13))
                        }
                    }
                }
                .foregroundStyle(isSelected ? .white : .primary)

                Spacer()

                // Arrow hint for images
                if isSelected && item.contentType == .image {
                    Text(isExpanded ? "\u{2190} to collapse" : "\u{2192} to preview")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(isSelected ? .white.opacity(0.6) : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isSelected ? .white.opacity(0.15) : Color.secondary.opacity(0.1))
                        )
                }

                // Shortcut badge (⌘1 – ⌘9)
                if index < 9 {
                    Text("⌘\(index + 1)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isSelected ? .white.opacity(0.2) : Color.secondary.opacity(0.12))
                        )
                }
            }

            // Expanded image preview
            if isExpanded, let nsImage = item.image {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
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
}
