import GRDB

protocol PlaybackPositionRepository {
    func upsert(source: TrackSource, sourceTrackId: String, position: Double, updatedAt: Int64) throws
    func fetchPosition(source: TrackSource, sourceTrackId: String) throws -> PlaybackPositionRecord?
}

final class GRDBPlaybackPositionRepository: PlaybackPositionRepository {
    private let dbWriter: DatabaseWriter

    init(dbWriter: DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func upsert(source: TrackSource, sourceTrackId: String, position: Double, updatedAt: Int64) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: """
                INSERT INTO playback_positions (source, source_track_id, position, updated_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(source, source_track_id)
                DO UPDATE SET position = excluded.position, updated_at = excluded.updated_at
                """,
                arguments: [source, sourceTrackId, position, updatedAt]
            )
        }
    }

    func fetchPosition(source: TrackSource, sourceTrackId: String) throws -> PlaybackPositionRecord? {
        try dbWriter.read { db in
            try PlaybackPositionRecord
                .filter(Column("source") == source && Column("source_track_id") == sourceTrackId)
                .fetchOne(db)
        }
    }
}
