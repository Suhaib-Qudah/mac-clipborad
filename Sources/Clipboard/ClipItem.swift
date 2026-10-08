import Foundation
import SwiftUI

enum ClipKind: String, Codable, CaseIterable {
    case text, link, image, video, file

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        case .video: "film"
        case .file: "doc.fill"
        }
    }

    var title: String {
        switch self {
        case .text: "Text"
        case .link: "Link"
        case .image: "Image"
        case .video: "Video"
        case .file: "File"
        }
    }

    var tint: Color {
        switch self {
        case .text: .blue
        case .link: .indigo
        case .image: .pink
        case .video: .purple
        case .file: .orange
        }
    }
}

struct ClipItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: ClipKind
    var text: String?
    var filePaths: [String]?
    var imageFile: String?
    var imageWidth: Double?
    var imageHeight: Double?
    var itemCount: Int?
    var pasteboardFile: String?
    var hash: String
    var sourceApp: String?
    var sourceBundleID: String?
    var date: Date
    var isPinned = false

    var title: String {
        switch kind {
        case .text, .link:
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
            return String(firstLine.prefix(200))
        case .image:
            if let count = itemCount, count > 1 { return "\(count) Images" }
            if let w = imageWidth, let h = imageHeight { return "Image \(Int(w)) × \(Int(h))" }
            return "Image"
        case .video:
            if let count = itemCount, count > 1 { return "\(count) Videos" }
            return "Video"
        case .file:
            let names = (filePaths ?? []).map { URL(fileURLWithPath: $0).lastPathComponent }
            if names.count > 1 { return "\(names[0]) + \(names.count - 1) more" }
            return names.first ?? "File"
        }
    }

    var searchableText: String {
        [text, filePaths?.joined(separator: " "), sourceApp, kind.title]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

enum ClipFilter: String, CaseIterable, Identifiable {
    case all, pinned, text, link, image, video, file

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .pinned: "Pinned"
        case .text: "Text"
        case .link: "Links"
        case .image: "Images"
        case .video: "Videos"
        case .file: "Files"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.stack"
        case .pinned: "pin"
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        case .video: "film"
        case .file: "doc"
        }
    }

    func matches(_ item: ClipItem) -> Bool {
        switch self {
        case .all: true
        case .pinned: item.isPinned
        case .text: item.kind == .text
        case .link: item.kind == .link
        case .image: item.kind == .image
        case .video: item.kind == .video
        case .file: item.kind == .file
        }
    }
}
