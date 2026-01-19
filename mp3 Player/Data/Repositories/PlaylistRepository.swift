import Foundation
import GRDB

protocol PlaylistRepository {
    func create(name: String, now: Int64) throws -> PlaylistRecord
    func rename(id: Int64, name: String, updatedAt: Int64) throws
    func delete(id: Int64) throws
    func fetchAll() throws -> [PlaylistRecord]
    func addTrack(playlistId: Int64, trackId: Int64, position: Int?, addedAt: Int64) throws
    func addTracks(playlistId: Int64, trackIds: [Int64], position: Int?, addedAt: Int64) throws
    func removeTrack(playlistId: Int64, trackId: Int64) throws
    func removeEntry(playlistId: Int64, ord: Int) throws
    func updateOrder(playlistId: Int64, entries: [PlaylistTrackEntry], updatedAt: Int64) throws
    func markPlayed(playlistId: Int64, playedAt: Int64) throws
    func fetchTrackIds(playlistId: Int64) throws -> [Int64]
}

struct PlaylistTrackEntry: Equatable {
    let trackId: Int64
    let addedAt: Int64
}

final class GRDBPlaylistRepository: PlaylistRepository {
    private let dbWriter: DatabaseWriter

    init(dbWriter: DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func create(name: String, now: Int64) throws -> PlaylistRecord {
        try dbWriter.write { db in
            var record = PlaylistRecord(
                id: nil,
                name: name,
                isFavorite: false,
                lastPlayedAt: nil,
                createdAt: now,
                updatedAt: now
            )
            try record.insert(db)
            record.id = db.lastInsertedRowID
            return record
        }
    }

    func rename(id: Int64, name: String, updatedAt: Int64) throws {
        _ = try dbWriter.write { db in
            try db.execute(
                sql: "UPDATE playlists SET name = ?, updated_at = ? WHERE id = ?",
                arguments: [name, updatedAt, id]
            )
        }
    }

    func delete(id: Int64) throws {
        _ = try dbWriter.write { db in
            try PlaylistRecord.deleteOne(db, key: id)
        }
    }

    func fetchAll() throws -> [PlaylistRecord] {
        try dbWriter.read { db in
            try PlaylistRecord
                .order(Column("updated_at").desc)
                .fetchAll(db)
        }
    }

    func addTrack(playlistId: Int64, trackId: Int64, position: Int?, addedAt: Int64) throws {
        _ = try dbWriter.write { db in
            try insertTracks(
                playlistId: playlistId,
                trackIds: [trackId],
                position: position,
                addedAt: addedAt,
                db: db
            )
            try db.execute(
                sql: "UPDATE playlists SET updated_at = ? WHERE id = ?",
                arguments: [addedAt, playlistId]
            )
        }
    }

    func addTracks(playlistId: Int64, trackIds: [Int64], position: Int?, addedAt: Int64) throws {
        guard !trackIds.isEmpty else { return }
        _ = try dbWriter.write { db in
            try insertTracks(
                playlistId: playlistId,
                trackIds: trackIds,
                position: position,
                addedAt: addedAt,
                db: db
            )
            try db.execute(
                sql: "UPDATE playlists SET updated_at = ? WHERE id = ?",
                arguments: [addedAt, playlistId]
            )
        }
    }

    func removeTrack(playlistId: Int64, trackId: Int64) throws {
        _ = try dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?",
                arguments: [playlistId, trackId]
            )
            let now = Int64(Date().timeIntervalSince1970)
            try db.execute(
                sql: "UPDATE playlists SET updated_at = ? WHERE id = ?",
                arguments: [now, playlistId]
            )
        }
    }

    func removeEntry(playlistId: Int64, ord: Int) throws {
        _ = try dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM playlist_tracks WHERE playlist_id = ? AND ord = ?",
                arguments: [playlistId, ord]
            )
            let now = Int64(Date().timeIntervalSince1970)
            try db.execute(
                sql: "UPDATE playlists SET updated_at = ? WHERE id = ?",
                arguments: [now, playlistId]
            )
        }
    }

    func updateOrder(playlistId: Int64, entries: [PlaylistTrackEntry], updatedAt: Int64) throws {
        _ = try dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM playlist_tracks WHERE playlist_id = ?",
                arguments: [playlistId]
            )
            for (index, entry) in entries.enumerated() {
                let record = PlaylistTrackRecord(
                    playlistId: playlistId,
                    trackId: entry.trackId,
                    ord: index,
                    addedAt: entry.addedAt
                )
                try record.insert(db)
            }
            try db.execute(
                sql: "UPDATE playlists SET updated_at = ? WHERE id = ?",
                arguments: [updatedAt, playlistId]
            )
        }
    }

    func markPlayed(playlistId: Int64, playedAt: Int64) throws {
        _ = try dbWriter.write { db in
            try db.execute(
                sql: "UPDATE playlists SET last_played_at = ? WHERE id = ?",
                arguments: [playedAt, playlistId]
            )
        }
    }

    func fetchTrackIds(playlistId: Int64) throws -> [Int64] {
        try dbWriter.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT track_id FROM playlist_tracks WHERE playlist_id = ? ORDER BY ord",
                arguments: [playlistId]
            )
            return rows.compactMap { $0["track_id"] }
        }
    }

    private func insertTracks(
        playlistId: Int64,
        trackIds: [Int64],
        position: Int?,
        addedAt: Int64,
        db: Database
    ) throws {
        let startOrd: Int
        if let position {
            try db.execute(
                sql: "UPDATE playlist_tracks SET ord = ord + ? WHERE playlist_id = ? AND ord >= ?",
                arguments: [trackIds.count, playlistId, position]
            )
            startOrd = position
        } else {
            let maxOrd: Int? = try Int.fetchOne(
                db,
                sql: "SELECT MAX(ord) FROM playlist_tracks WHERE playlist_id = ?",
                arguments: [playlistId]
            )
            startOrd = (maxOrd ?? -1) + 1
        }

        for (index, trackId) in trackIds.enumerated() {
            let record = PlaylistTrackRecord(
                playlistId: playlistId,
                trackId: trackId,
                ord: startOrd + index,
                addedAt: addedAt
            )
            try record.insert(db)
        }
    }
}
