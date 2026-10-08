import SwiftUI

struct PreviewPane: View {
    let item: ClipItem?
    let store: ClipboardStore

    var body: some View {
        if let item {
            VStack(spacing: 0) {
                content(for: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider().opacity(0.6)
                InfoSection(item: item, store: store)
            }
        } else {
            ContentUnavailableView(
                "Clipboard History",
                systemImage: "list.clipboard",
                description: Text("Press ⇧⌘V anywhere to open this window.")
            )
        }
    }

    @ViewBuilder
    private func content(for item: ClipItem) -> some View {
        switch item.kind {
        case .text:
            ScrollView {
                Text(String((item.text ?? "").prefix(20_000)))
                    .font(.system(size: 13, design: looksLikeCode(item.text ?? "") ? .monospaced : .default))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
        case .link:
            LinkPreview(text: item.text ?? "")
        case .image, .video:
            if let image = store.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                    .overlay {
                        if item.kind == .video {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.3), radius: 6)
                        }
                    }
                    .padding(24)
            }
        case .file:
            FilePreview(paths: item.filePaths ?? [])
        }
    }

    private func looksLikeCode(_ text: String) -> Bool {
        let markers = ["{", "}", ";", "=>", "func ", "def ", "const ", "import ", "</", "#include"]
        return markers.filter { text.contains($0) }.count >= 2
    }
}

private struct LinkPreview: View {
    let text: String

    private var url: URL? { URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) }

    var body: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.indigo.gradient)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "safari")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.white)
                }
                .shadow(color: .indigo.opacity(0.35), radius: 8, y: 3)
            Text(url?.host() ?? "Link")
                .font(.system(size: 17, weight: .semibold))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .textSelection(.enabled)
                .padding(.horizontal, 28)
            if let url {
                Button("Open in Browser", systemImage: "arrow.up.right") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.glass)
                .controlSize(.regular)
            }
        }
        .padding()
    }
}

private struct FilePreview: View {
    let paths: [String]

    var body: some View {
        if paths.count == 1, let path = paths.first {
            VStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 96, height: 96)
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.system(size: 15, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text(path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 28)
                Button("Show in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                }
                .buttonStyle(.glass)
            }
            .padding()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(paths, id: \.self) { path in
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                .resizable()
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.system(size: 13, weight: .medium))
                                Text(path)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
    }
}

private struct InfoSection: View {
    let item: ClipItem
    let store: ClipboardStore

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                label("Source")
                HStack(spacing: 6) {
                    if let icon = store.appIcon(for: item.sourceBundleID) {
                        Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                    }
                    Text(item.sourceApp ?? "Unknown")
                }
            }
            GridRow {
                label("Content type")
                Text(item.kind.title)
            }
            ForEach(details, id: \.0) { title, value in
                GridRow {
                    label(title)
                    Text(value).monospacedDigit()
                }
            }
            GridRow {
                label("Copied")
                Text(item.date.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
    }

    private var details: [(String, String)] {
        switch item.kind {
        case .text, .link:
            let text = item.text ?? ""
            let words = text.split { $0.isWhitespace || $0.isNewline }.count
            return [
                ("Characters", text.count.formatted()),
                ("Words", words.formatted()),
            ]
        case .image, .video:
            var rows: [(String, String)] = []
            if let count = item.itemCount, count > 1 {
                rows.append(("Items", count.formatted()))
            }
            if let w = item.imageWidth, let h = item.imageHeight {
                rows.append(("Dimensions", "\(Int(w)) × \(Int(h))"))
                if let size = store.imageFileSize(for: item) {
                    rows.append(("Size", ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))
                }
            }
            return rows
        case .file:
            return [("Items", (item.filePaths?.count ?? 0).formatted())]
        }
    }
}
