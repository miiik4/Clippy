import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Type icon / thumbnail
            Group {
                switch item.contentType {
                case .text:
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.blue.opacity(0.15))
                        Image(systemName: "doc.text")
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                    }

                case .image:
                    if let nsImage = item.image {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.green.opacity(0.15))
                            Image(systemName: "photo")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                        }
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
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : .clear)
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
    }
}
