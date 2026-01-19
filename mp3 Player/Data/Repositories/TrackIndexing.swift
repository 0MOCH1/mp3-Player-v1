import GRDB

enum TrackIndexing {
    nonisolated static func reindex(trackId: Int64, db: Database) throws {
        let row = try Row.fetchOne(
            db,
            sql: """
            SELECT
                t.id AS id,
                t.title AS base_title,
                t.genre AS base_genre,
                mo.title AS override_title,
                mo.artist_name AS override_artist,
                mo.album_name AS override_album,
                mo.genre AS override_genre,
                a.name AS artist_name,
                al.name AS album_name,
                (
                    SELECT content
                    FROM lyrics
                    WHERE source = t.source AND source_track_id = t.source_track_id
                    ORDER BY provider
                    LIMIT 1
                ) AS lyrics
            FROM tracks t
            LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
            LEFT JOIN artists a ON a.id = t.artist_id
            LEFT JOIN albums al ON al.id = t.album_id
            WHERE t.id = ?
            """,
            arguments: [trackId]
        )

        guard let row else { return }

        let title = (row["override_title"] as String?)
            ?? (row["base_title"] as String?)
            ?? ""
        let artist = (row["override_artist"] as String?) ?? (row["artist_name"] as String?)
        let album = (row["override_album"] as String?) ?? (row["album_name"] as String?)
        let genre = (row["override_genre"] as String?) ?? (row["base_genre"] as String?)
        let lyrics = row["lyrics"] as String?

        try db.execute(
            sql: """
            INSERT OR REPLACE INTO tracks_fts
            (rowid, track_id, title, artist, album, genre, lyrics)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [trackId, trackId, title, artist, album, genre, lyrics]
        )
    }
}
