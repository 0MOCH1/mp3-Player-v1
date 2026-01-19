import Foundation
import GRDB

final class AppDatabase {
    let dbPool: DatabasePool
    let repositories: AppRepositories

    init(directory: URL = AppDatabase.defaultDirectory) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dbURL = directory.appendingPathComponent("app.sqlite")

        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }

        dbPool = try DatabasePool(path: dbURL.path, configuration: config)
        try AppDatabase.migrator.migrate(dbPool)
        repositories = AppRepositories(dbWriter: dbPool)
    }

    static var defaultDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleId = Bundle.main.bundleIdentifier ?? "mp3-player"
        return appSupport.appendingPathComponent(bundleId, isDirectory: true)
    }
}
