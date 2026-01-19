import Foundation
import ImageIO

enum ArtworkStorage {
    nonisolated static func storeArtwork(
        data: Data,
        hash: String,
        baseDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = try ensureArtworkDirectory(baseDirectory: baseDirectory, fileManager: fileManager)
        let ext = fileExtension(for: data)
        let fileName = ext.isEmpty ? hash : "\(hash).\(ext)"
        let destination = directory.appendingPathComponent(fileName)
        if !fileManager.fileExists(atPath: destination.path) {
            try data.write(to: destination, options: .atomic)
        }
        return destination
    }

    nonisolated static func imageSize(for data: Data) -> (Int?, Int?) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return (nil, nil)
        }
        let width = props[kCGImagePropertyPixelWidth] as? Int
        let height = props[kCGImagePropertyPixelHeight] as? Int
        return (width, height)
    }

    nonisolated private static func ensureArtworkDirectory(
        baseDirectory: URL,
        fileManager: FileManager
    ) throws -> URL {
        let directory = baseDirectory.appendingPathComponent("Artworks", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    nonisolated private static func fileExtension(for data: Data) -> String {
        if data.starts(with: Data([0xFF, 0xD8])) {
            return "jpg"
        }
        if data.starts(with: Data([0x89, 0x50, 0x4E, 0x47])) {
            return "png"
        }
        return "bin"
    }
}
