import Foundation
import GRDB

struct TrackDeletionResult {
    let deletedFile: Bool
    let importMode: ImportMode?
}

final class TrackDeletionService {
    private let appDatabase: AppDatabase
    private let fileManager: FileManager

    init(appDatabase: AppDatabase, fileManager: FileManager = .default) {
        self.appDatabase = appDatabase
        self.fileManager = fileManager
    }

    func deleteTrack(trackId: Int64) async throws -> TrackDeletionResult {
        let info = try await appDatabase.dbPool.read { db -> (source: TrackSource, sourceTrackId: String, fileUri: String?, importMode: ImportMode?)? in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT
                    t.source AS source,
                    t.source_track_id AS source_track_id,
                    t.file_uri AS file_uri,
                    ir.import_mode AS import_mode
                FROM tracks t
                LEFT JOIN import_records ir ON ir.track_id = t.id
                WHERE t.id = ?
                ORDER BY ir.updated_at DESC
                LIMIT 1
                """,
                arguments: [trackId]
            )
            guard let row else { return nil }
            let sourceRaw = row["source"] as String? ?? TrackSource.local.rawValue
            let source = TrackSource(rawValue: sourceRaw) ?? .local
            let sourceTrackId = row["source_track_id"] as String? ?? ""
            let fileUri = row["file_uri"] as String?
            let modeRaw = row["import_mode"] as String?
            let importMode = modeRaw.flatMap { ImportMode(rawValue: $0) }
            return (source, sourceTrackId, fileUri, importMode)
        }

        guard let info else {
            throw NSError(domain: "TrackDeletion", code: 1, userInfo: [NSLocalizedDescriptionKey: "Track not found."])
        }

        var deletedFile = false
        if info.source == .local,
           let mode = info.importMode,
           mode != .reference,
           let fileUri = info.fileUri,
           let url = URL(string: fileUri),
           url.isFileURL {
            if let libraryDir = try? LocalImportPaths.libraryFilesDirectory(fileManager: fileManager),
               url.path.hasPrefix(libraryDir.path) {
                if fileManager.fileExists(atPath: url.path) {
                    try? fileManager.removeItem(at: url)
                    deletedFile = true
                }
            }
        }

        try await appDatabase.dbPool.write { db in
            try db.execute(
                sql: "DELETE FROM queue_items WHERE source = ? AND source_track_id = ?",
                arguments: [info.source, info.sourceTrackId]
            )
            try db.execute(
                sql: "DELETE FROM history_entries WHERE source = ? AND source_track_id = ?",
                arguments: [info.source, info.sourceTrackId]
            )
            try db.execute(
                sql: "DELETE FROM playback_positions WHERE source = ? AND source_track_id = ?",
                arguments: [info.source, info.sourceTrackId]
            )
            try db.execute(
                sql: "DELETE FROM playback_state WHERE source = ? AND source_track_id = ?",
                arguments: [info.source, info.sourceTrackId]
            )
            try db.execute(
                sql: "DELETE FROM lyrics WHERE source = ? AND source_track_id = ?",
                arguments: [info.source, info.sourceTrackId]
            )
            try db.execute(
                sql: "DELETE FROM metadata_overrides WHERE track_id = ?",
                arguments: [trackId]
            )
            try db.execute(
                sql: "DELETE FROM playlist_tracks WHERE track_id = ?",
                arguments: [trackId]
            )
            try db.execute(
                sql: "DELETE FROM import_records WHERE track_id = ?",
                arguments: [trackId]
            )
            try db.execute(
                sql: "DELETE FROM tracks_fts WHERE rowid = ?",
                arguments: [trackId]
            )
            try db.execute(
                sql: "DELETE FROM tracks WHERE id = ?",
                arguments: [trackId]
            )
        }

        return TrackDeletionResult(deletedFile: deletedFile, importMode: info.importMode)
    }
}
