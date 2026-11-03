import AppKit
import AVFoundation
import UniformTypeIdentifiers

/// Imports a photo or video for the header into the shared container and makes a still for the widgets.
enum HeaderMedia {
    static let posterName = "header-poster.jpg"
    static let maxVideoBytes = 400 * 1024 * 1024

    enum Failure: LocalizedError {
        case tooLarge, unreadable
        var errorDescription: String? {
            switch self {
            case .tooLarge: return "That video is over 400 MB. Pick a shorter clip."
            case .unreadable: return "Couldn't read that file."
            }
        }
    }

    /// Copies the file in, returns the stored file name and kind.
    static func importFile(_ src: URL) async throws -> (String, MediaKind) {
        let type = UTType(filenameExtension: src.pathExtension.lowercased())
        let isVideo = type?.conforms(to: .movie) ?? false || type?.conforms(to: .audiovisualContent) ?? false
        let dir = Prefs.containerURL
        let token = UUID().uuidString.prefix(8)

        if isVideo {
            let size = (try? src.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size <= maxVideoBytes else { throw Failure.tooLarge }
            let name = "header-\(token).\(src.pathExtension.lowercased())"
            let dst = dir.appendingPathComponent(name)
            try FileManager.default.copyItem(at: src, to: dst)
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: dst))
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 640, height: 640)   // widgets reject big images
            if let still = try? await gen.image(at: CMTime(seconds: 1, preferredTimescale: 600)).image {
                writeJPEG(still, to: dir.appendingPathComponent(posterName))
            }
            return (name, .video)
        }

        // Photos are scaled down: the header is at most 440 pt wide.
        guard let source = CGImageSourceCreateWithURL(src as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 1400,
              ] as CFDictionary)
        else { throw Failure.unreadable }
        let name = "header-\(token).jpg"
        let stored = dir.appendingPathComponent(name)
        writeJPEG(image, to: stored)
        if let small = CGImageSourceCreateWithURL(stored as CFURL, nil).flatMap({
            CGImageSourceCreateThumbnailAtIndex($0, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                                        kCGImageSourceThumbnailMaxPixelSize: 640] as CFDictionary)
        }) {
            writeJPEG(small, to: dir.appendingPathComponent(posterName))
        }
        return (name, .image)
    }

    static func remove(_ file: String?) {
        guard let file else { return }
        try? FileManager.default.removeItem(at: Prefs.containerURL.appendingPathComponent(file))
    }

    static func removePoster() {
        try? FileManager.default.removeItem(at: Prefs.containerURL.appendingPathComponent(posterName))
    }

    private static func writeJPEG(_ image: CGImage, to url: URL) {
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])?.write(to: url, options: .atomic)
    }
}
