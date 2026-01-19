import GRDB

protocol PlaybackStateRepository {
    func upsert(source: TrackSource, sourceTrackId: String, queueIndex: Int, updatedAt: Int64) throws
    func fetch() throws -> PlaybackStateRecord?
}

final class GRDBPlaybackStateRepository: PlaybackStateRepository {
    private let dbWriter: DatabaseWriter

    init(dbWriter: DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func upsert(source: TrackSource, sourceTrackId: String, queueIndex: Int, updatedAt: Int64) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: """
                INSERT INTO playback_state (id, source, source_track_id, queue_index, updated_at)
                VALUES (1, ?, ?, ?, ?)
                ON CONFLICT(id)
                DO UPDATE SET
                    source = excluded.source,
                    source_track_id = excluded.source_track_id,
                    queue_index = excluded.queue_index,
                    updated_at = excluded.updated_at
                """,
                arguments: [source, sourceTrackId, queueIndex, updatedAt]
            )
        }
    }

    func fetch() throws -> PlaybackStateRecord? {
        try dbWriter.read { db in
            try PlaybackStateRecord.fetchOne(db, key: 1)
        }
    }
}
