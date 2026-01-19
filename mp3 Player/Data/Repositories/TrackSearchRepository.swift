import Foundation
import GRDB

struct TrackSearchEntry {
    let trackId: Int64
    let title: String?
    let artist: String?
    let album: String?
    let genre: String?
    let lyrics: String?
}

protocol TrackSearchRepository {
    func index(_ entry: TrackSearchEntry) throws
    func remove(trackId: Int64) throws
    func search(query: String, limit: Int) throws -> [Int64]
}

final class GRDBTrackSearchRepository: TrackSearchRepository {
    private let dbWriter: DatabaseWriter

    init(dbWriter: DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func index(_ entry: TrackSearchEntry) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO tracks_fts
                (rowid, track_id, title, artist, album, genre, lyrics)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    entry.trackId,
                    entry.trackId,
                    entry.title,
                    entry.artist,
                    entry.album,
                    entry.genre,
                    entry.lyrics,
                ]
            )
        }
    }

    func remove(trackId: Int64) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM tracks_fts WHERE rowid = ?",
                arguments: [trackId]
            )
        }
    }

    func search(query: String, limit: Int) throws -> [Int64] {
        try dbWriter.read { db in
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }
            guard let pattern = FTS5Pattern(matchingAnyTokenIn: trimmed) else { return [] }
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT track_id
                FROM tracks_fts
                WHERE tracks_fts MATCH ?
                ORDER BY bm25(tracks_fts)
                LIMIT ?
                """,
                arguments: [pattern, limit]
            )
            return rows.compactMap { $0["track_id"] }
        }
    }
}
