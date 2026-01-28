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

struct FavoriteAlbumSummary: Identifiable {
    let id: Int64
    let name: String
    let artist: String?
    let artworkUri: String?
    let isFavorite: Bool
}

struct FavoritePlaylistSummary: Identifiable {
    let id: Int64
    let name: String
    let artworkUris: [String?]
    let isFavorite: Bool
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var counts = LibraryCounts(tracks: 0, albums: 0, artists: 0, playlists: 0, favorites: 0)
    @Published var tracks: [TrackSummary] = []
    @Published var missingTracks: [MissingTrackSummary] = []
    @Published var playlists: [PlaylistSummary] = []
    @Published var favoriteTracks: [TrackSummary] = []
    @Published var favoriteAlbums: [FavoriteAlbumSummary] = []
    @Published var favoritePlaylists: [FavoritePlaylistSummary] = []

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
        let snapshot = (try? await appDatabase.dbPool.read { db -> (LibraryCounts, [TrackSummary], [MissingTrackSummary], [PlaylistSummary], [TrackSummary], [FavoriteAlbumSummary], [FavoritePlaylistSummary]) in
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
            
            // Fetch favorite albums (max 6 for pinned section)
            let favoriteAlbumRows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    a.id AS id,
                    a.name AS name,
                    COALESCE(ar.name, MIN(tr.name)) AS artist_name,
                    a.is_favorite AS is_favorite,
                    aw.file_uri AS artwork_uri
                FROM albums a
                LEFT JOIN artists ar ON ar.id = a.album_artist_id
                LEFT JOIN tracks t ON t.album_id = a.id
                LEFT JOIN artists tr ON tr.id = t.artist_id
                LEFT JOIN artworks aw ON aw.id = a.artwork_id
                WHERE a.is_favorite = 1
                GROUP BY a.id
                ORDER BY a.updated_at DESC
                LIMIT 6
                """
            )
            let favoriteAlbumSummaries = favoriteAlbumRows.compactMap { row -> FavoriteAlbumSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Unknown Album"
                let artist = row["artist_name"] as String?
                let artworkUri = row["artwork_uri"] as String?
                let isFavorite = row["is_favorite"] as Bool? ?? true
                return FavoriteAlbumSummary(
                    id: id,
                    name: name,
                    artist: artist,
                    artworkUri: artworkUri,
                    isFavorite: isFavorite
                )
            }
            
            // Fetch favorite playlists (max 6 for pinned section)
            let favoritePlaylistRows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, name, is_favorite
                FROM playlists
                WHERE is_favorite = 1
                ORDER BY updated_at DESC
                LIMIT 6
                """
            )
            var favoritePlaylists = favoritePlaylistRows.compactMap { row -> FavoritePlaylistSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Untitled Playlist"
                let isFavorite = row["is_favorite"] as Bool? ?? true
                return FavoritePlaylistSummary(id: id, name: name, artworkUris: [], isFavorite: isFavorite)
            }
            
            // Fetch artwork for favorite playlists
            let playlistIds = favoritePlaylists.map { $0.id }
            if !playlistIds.isEmpty {
                let placeholders = playlistIds.map { _ in "?" }.joined(separator: ",")
                let artworkRows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT
                        pt.playlist_id AS playlist_id,
                        aw.file_uri AS artwork_uri
                    FROM playlist_tracks pt
                    JOIN tracks t ON t.id = pt.track_id
                    LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                    LEFT JOIN artworks aw
                        ON aw.id = COALESCE(mo.artwork_id, t.artwork_id, t.album_artwork_id)
                    WHERE pt.playlist_id IN (\(placeholders))
                    ORDER BY pt.playlist_id, pt.ord
                    """,
                    arguments: StatementArguments(playlistIds)
                )
                var artworkMap: [Int64: [String?]] = [:]
                for row in artworkRows {
                    guard let playlistId = row["playlist_id"] as Int64? else { continue }
                    var list = artworkMap[playlistId] ?? []
                    if list.count >= 4 { continue }
                    let uri = row["artwork_uri"] as String?
                    list.append(uri)
                    artworkMap[playlistId] = list
                }
                favoritePlaylists = favoritePlaylists.map { playlist in
                    FavoritePlaylistSummary(
                        id: playlist.id,
                        name: playlist.name,
                        artworkUris: artworkMap[playlist.id] ?? [],
                        isFavorite: playlist.isFavorite
                    )
                }
            }

            return (counts, summaries, missingSummaries, playlistSummaries, favoriteSummaries, favoriteAlbumSummaries, favoritePlaylists)
        }) ?? (
            LibraryCounts(tracks: 0, albums: 0, artists: 0, playlists: 0, favorites: 0),
            [],
            [],
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
        self.favoriteAlbums = snapshot.5
        self.favoritePlaylists = snapshot.6
    }
}
