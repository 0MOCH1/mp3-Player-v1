import Combine
import Foundation
import GRDB

struct LibraryCounts {
    let tracks: Int
    let albums: Int
    let artists: Int
    let playlists: Int
    let favorites: Int
}

struct TrackSummary: Identifiable {
    let id: Int64
    let title: String
    let artist: String?
    let isFavorite: Bool
}

struct MissingTrackSummary: Identifiable {
    let id: Int64
    let title: String
    let artist: String?
    let missingReason: String?
}

struct PlaylistSummary: Identifiable {
    let id: Int64
    let name: String
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var counts = LibraryCounts(tracks: 0, albums: 0, artists: 0, playlists: 0, favorites: 0)
    @Published var tracks: [TrackSummary] = []
    @Published var missingTracks: [MissingTrackSummary] = []
    @Published var playlists: [PlaylistSummary] = []
    @Published var favoriteTracks: [TrackSummary] = []

    private var didLoad = false

    func loadIfNeeded(appDatabase: AppDatabase?) {
        guard !didLoad, let appDatabase else { return }
        didLoad = true

        Task {
            await loadData(appDatabase: appDatabase)
        }
    }

    func reload(appDatabase: AppDatabase?) {
        guard let appDatabase else { return }
        Task {
            await loadData(appDatabase: appDatabase)
        }
    }

    private func loadData(appDatabase: AppDatabase) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> (LibraryCounts, [TrackSummary], [MissingTrackSummary], [PlaylistSummary], [TrackSummary]) in
            let tracks = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM tracks") ?? 0
            let albums = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM albums") ?? 0
            let artists = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM artists") ?? 0
            let playlists = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM playlists") ?? 0
            let favorites = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM tracks WHERE is_favorite = 1") ?? 0
            let counts = LibraryCounts(
                tracks: tracks,
                albums: albums,
                artists: artists,
                playlists: playlists,
                favorites: favorites
            )

            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    t.id AS id,
                    COALESCE(mo.title, t.title) AS title,
                    COALESCE(mo.artist_name, a.name) AS artist_name,
                    t.is_favorite AS is_favorite
                FROM tracks t
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN artists a ON a.id = t.artist_id
                ORDER BY t.id DESC
                LIMIT 50
                """
            )
            let summaries = rows.compactMap { row -> TrackSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let title = row["title"] as String? ?? "Unknown Title"
                let artist = row["artist_name"] as String?
                let isFavorite = row["is_favorite"] as Bool? ?? false
                return TrackSummary(id: id, title: title, artist: artist, isFavorite: isFavorite)
            }
            let missingRows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    t.id AS id,
                    COALESCE(mo.title, t.title) AS title,
                    COALESCE(mo.artist_name, a.name) AS artist_name,
                    t.missing_reason AS missing_reason
                FROM tracks t
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN artists a ON a.id = t.artist_id
                WHERE t.is_missing = 1
                ORDER BY t.updated_at DESC
                LIMIT 50
                """
            )
            let missingSummaries = missingRows.compactMap { row -> MissingTrackSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let title = row["title"] as String? ?? "Unknown Title"
                let artist = row["artist_name"] as String?
                let reason = row["missing_reason"] as String?
                return MissingTrackSummary(id: id, title: title, artist: artist, missingReason: reason)
            }
            let playlistRows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, name
                FROM playlists
                ORDER BY updated_at DESC
                LIMIT 50
                """
            )
            let playlistSummaries = playlistRows.compactMap { row -> PlaylistSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Untitled Playlist"
                return PlaylistSummary(id: id, name: name)
            }

            let favoriteRows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    t.id AS id,
                    COALESCE(mo.title, t.title) AS title,
                    COALESCE(mo.artist_name, a.name) AS artist_name,
                    t.is_favorite AS is_favorite
                FROM tracks t
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN artists a ON a.id = t.artist_id
                WHERE t.is_favorite = 1
                ORDER BY t.updated_at DESC
                LIMIT 50
                """
            )
            let favoriteSummaries = favoriteRows.compactMap { row -> TrackSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let title = row["title"] as String? ?? "Unknown Title"
                let artist = row["artist_name"] as String?
                let isFavorite = row["is_favorite"] as Bool? ?? true
                return TrackSummary(id: id, title: title, artist: artist, isFavorite: isFavorite)
            }

            return (counts, summaries, missingSummaries, playlistSummaries, favoriteSummaries)
        }) ?? (
            LibraryCounts(tracks: 0, albums: 0, artists: 0, playlists: 0, favorites: 0),
            [],
            [],
            [],
            []
        )

        self.counts = snapshot.0
        self.tracks = snapshot.1
        self.missingTracks = snapshot.2
        self.playlists = snapshot.3
        self.favoriteTracks = snapshot.4
    }
}
