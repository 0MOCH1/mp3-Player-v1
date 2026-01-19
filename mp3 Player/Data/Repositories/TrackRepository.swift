import GRDB

protocol TrackRepository {
    func upsert(_ record: TrackRecord) throws
    func fetch(byId id: Int64) throws -> TrackRecord?
    func fetch(bySource source: TrackSource, sourceTrackId: String) throws -> TrackRecord?
    func fetchAll(limit: Int) throws -> [TrackRecord]
}

final class GRDBTrackRepository: TrackRepository {
    private let dbWriter: DatabaseWriter
    private enum TrackRepositoryError: Error {
        case missingTrackId
    }

    init(dbWriter: DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func upsert(_ record: TrackRecord) throws {
        try dbWriter.write { db in
            let trackId = try upsertRecord(record, db: db)
            try TrackIndexing.reindex(trackId: trackId, db: db)
        }
    }

    func fetch(byId id: Int64) throws -> TrackRecord? {
        try dbWriter.read { db in
            try TrackRecord.fetchOne(db, key: id)
        }
    }

    func fetch(bySource source: TrackSource, sourceTrackId: String) throws -> TrackRecord? {
        try dbWriter.read { db in
            try TrackRecord
                .filter(Column("source") == source && Column("source_track_id") == sourceTrackId)
                .fetchOne(db)
        }
    }

    func fetchAll(limit: Int) throws -> [TrackRecord] {
        try dbWriter.read { db in
            try TrackRecord
                .order(Column("id").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    private func upsertRecord(_ record: TrackRecord, db: Database) throws -> Int64 {
        try db.execute(
            sql: """
            INSERT INTO tracks (
                id,
                source,
                source_track_id,
                title,
                duration,
                file_uri,
                content_hash,
                file_size,
                track_number,
                disc_number,
                is_missing,
                missing_reason,
                is_favorite,
                album_id,
                artist_id,
                album_artist_id,
                genre,
                release_year,
                artwork_id,
                album_artwork_id,
                created_at,
                updated_at
            ) VALUES (
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            ON CONFLICT(source, source_track_id)
            DO UPDATE SET
                title = excluded.title,
                duration = excluded.duration,
                file_uri = excluded.file_uri,
                content_hash = excluded.content_hash,
                file_size = excluded.file_size,
                track_number = excluded.track_number,
                disc_number = excluded.disc_number,
                is_missing = excluded.is_missing,
                missing_reason = excluded.missing_reason,
                is_favorite = excluded.is_favorite,
                album_id = excluded.album_id,
                artist_id = excluded.artist_id,
                album_artist_id = excluded.album_artist_id,
                genre = excluded.genre,
                release_year = excluded.release_year,
                artwork_id = excluded.artwork_id,
                album_artwork_id = excluded.album_artwork_id,
                updated_at = excluded.updated_at
            """,
            arguments: [
                record.id,
                record.source,
                record.sourceTrackId,
                record.title,
                record.duration,
                record.fileUri,
                record.contentHash,
                record.fileSize,
                record.trackNumber,
                record.discNumber,
                record.isMissing,
                record.missingReason,
                record.isFavorite,
                record.albumId,
                record.artistId,
                record.albumArtistId,
                record.genre,
                record.releaseYear,
                record.artworkId,
                record.albumArtworkId,
                record.createdAt,
                record.updatedAt,
            ]
        )

        guard let trackId = try Int64.fetchOne(
            db,
            sql: "SELECT id FROM tracks WHERE source = ? AND source_track_id = ?",
            arguments: [record.source, record.sourceTrackId]
        ) else {
            throw TrackRepositoryError.missingTrackId
        }

        return trackId
    }

}
