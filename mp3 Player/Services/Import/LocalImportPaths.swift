import Foundation

enum LocalImportPaths {
    static func libraryFilesDirectory(fileManager: FileManager = .default) throws -> URL {
        let base = AppDatabase.defaultDirectory
        let directory = base.appendingPathComponent("LibraryFiles", isDirectory: true)
        return try ensureDirectory(directory, fileManager: fileManager)
    }

    static func appImportDirectory(fileManager: FileManager = .default) throws -> URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = documents.appendingPathComponent("Import", isDirectory: true)
        return try ensureDirectory(directory, fileManager: fileManager)
    }

    static func scanDirectories(fileManager: FileManager = .default) throws -> [URL] {
        [
            try libraryFilesDirectory(fileManager: fileManager),
            try appImportDirectory(fileManager: fileManager),
        ]
    }

    private static func ensureDirectory(_ url: URL, fileManager: FileManager) throws -> URL {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
}
