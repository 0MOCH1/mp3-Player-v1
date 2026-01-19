import Foundation
import GRDB

protocol ListeningStatsRepository {
    func increment(artistId: Int64, day: Int, count: Int) throws
    func topArtists(sinceDay: Int, limit: Int) throws -> [Int64]
    func prune(olderThanDay: Int) throws
}

final class GRDBListeningStatsRepository: ListeningStatsRepository {
    private let dbWriter: DatabaseWriter

    init(dbWriter: DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func increment(artistId: Int64, day: Int, count: Int) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: """
                INSERT INTO listening_stats (artist_id, day, play_count)
                VALUES (?, ?, ?)
                ON CONFLICT(artist_id, day)
                DO UPDATE SET play_count = play_count + ?
                """,
                arguments: [artistId, day, count, count]
            )
        }
    }

    func topArtists(sinceDay: Int, limit: Int) throws -> [Int64] {
        try dbWriter.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT artist_id, SUM(play_count) AS total
                FROM listening_stats
                WHERE day >= ?
                GROUP BY artist_id
                ORDER BY total DESC
                LIMIT ?
                """,
                arguments: [sinceDay, limit]
            )
            return rows.compactMap { $0["artist_id"] }
        }
    }

    func prune(olderThanDay: Int) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM listening_stats WHERE day < ?",
                arguments: [olderThanDay]
            )
        }
    }
}
