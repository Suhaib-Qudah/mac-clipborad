import SwiftUI

struct ClipRow: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    let store: ClipboardStore

    var body: some View {
        HStack(spacing: 11) {
            ClipThumbnail(item: item, store: store, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let app = item.sourceApp {
                        Text(app)
                        Text("·")
                    }
                    Text(item.date, format: .relative(presentation: .named))
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.orange))
                    .rotationEffect(.degrees(45))
            }
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.accentColor.gradient)
            }
        }
        .contentShape(.rect(cornerRadius: 11))
    }
}

struct ClipThumbnail: View {
    let item: ClipItem
    let store: ClipboardStore
    let size: CGFloat

    var body: some View {
        Group {
            switch item.kind {
            case .image, .video:
                if let image = store.image(for: item) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(.rect(cornerRadius: size * 0.24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                                .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                        }
                        .overlay {
                            if item.kind == .video {
                                Image(systemName: "play.fill")
                                    .font(.system(size: size * 0.32, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2)
                            }
                        }
                } else {
                    symbolTile
                }
            case .file:
                if let path = item.filePaths?.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .frame(width: size, height: size)
                } else {
                    symbolTile
                }
            case .text, .link:
                symbolTile
            }
        }
        .frame(width: size, height: size)
    }

    private var symbolTile: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(item.kind.tint.gradient)
            .overlay {
                Image(systemName: item.kind.symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: item.kind.tint.opacity(0.3), radius: 2, y: 1)
    }
}
