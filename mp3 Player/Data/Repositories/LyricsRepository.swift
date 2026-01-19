import GRDB

protocol LyricsRepository {
    func upsert(_ record: LyricsRecord) throws
    func delete(source: TrackSource, sourceTrackId: String, provider: String) throws
}

final class GRDBLyricsRepository: LyricsRepository {
    private let dbWriter: DatabaseWriter

    init(dbWriter: DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func upsert(_ record: LyricsRecord) throws {
        try dbWriter.write { db in
            try record.save(db)
            try reindexIfPossible(source: record.source, sourceTrackId: record.sourceTrackId, db: db)
        }
    }

    func delete(source: TrackSource, sourceTrackId: String, provider: String) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM lyrics WHERE source = ? AND source_track_id = ? AND provider = ?",
                arguments: [source, sourceTrackId, provider]
            )
            try reindexIfPossible(source: source, sourceTrackId: sourceTrackId, db: db)
        }
    }

    private func reindexIfPossible(source: TrackSource, sourceTrackId: String, db: Database) throws {
        let trackId = try Int64.fetchOne(
            db,
            sql: "SELECT id FROM tracks WHERE source = ? AND source_track_id = ?",
            arguments: [source, sourceTrackId]
        )
        if let trackId {
            try TrackIndexing.reindex(trackId: trackId, db: db)
        }
    }
}
