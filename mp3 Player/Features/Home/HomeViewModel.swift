import Combine
import Foundation
import GRDB

struct RecentAlbumSummary: Identifiable {
    let id: Int64
    let name: String
    let albumArtist: String?
    let artworkUri: String?
    let isFavorite: Bool
}

struct RecentPlaylistSummary: Identifiable {
    let id: Int64
    let name: String
    let artworkUris: [String?]
    let isFavorite: Bool
}

struct RecentTrackSummary: Identifiable {
    let id: Int64
    let trackId: Int64?
    let source: TrackSource
    let sourceTrackId: String
    let title: String
    let artist: String?
    let artworkUri: String?
    let isFavorite: Bool
}

struct TopArtistSummary: Identifiable {
    let id: Int64
    let name: String
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recentAlbums: [RecentAlbumSummary] = []
    @Published var recentPlaylists: [RecentPlaylistSummary] = []
    @Published var recentTracks: [RecentTrackSummary] = []
    @Published var topArtists: [TopArtistSummary] = []

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
    
    func loadAllRecentPlays(appDatabase: AppDatabase) async -> ([RecentAlbumSummary], [RecentPlaylistSummary]) {
        return await loadRecentPlays(appDatabase: appDatabase, limit: 100)
    }
    
    func loadAllRecentTracks(appDatabase: AppDatabase) async -> [RecentTrackSummary] {
        return await loadRecentTracksData(appDatabase: appDatabase, limit: 100)
    }

    private func loadData(appDatabase: AppDatabase) async {
        let (albums, playlists) = await loadRecentPlays(appDatabase: appDatabase, limit: 15)
        let tracks = await loadRecentTracksData(appDatabase: appDatabase, limit: 10)
        let artists = await loadTopArtists(appDatabase: appDatabase)
        
        recentAlbums = albums
        recentPlaylists = playlists
        recentTracks = tracks
        topArtists = artists
    }
    
    private func loadRecentPlays(appDatabase: AppDatabase, limit: Int) async -> ([RecentAlbumSummary], [RecentPlaylistSummary]) {
        let sinceDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let sinceDay = DateUtils.yyyymmdd(sinceDate)

        let snapshot = (try? await appDatabase.dbPool.read { db -> ([RecentAlbumSummary], [RecentPlaylistSummary]) in
            let albumRows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    r.entity_id AS id,
                    r.last_opened_at AS last_opened_at,
                    a.name AS name,
                    COALESCE(ar.name, MIN(tr.name)) AS album_artist_name,
                    a.is_favorite AS is_favorite,
                    aw.file_uri AS artwork_uri
                FROM recent_items r
                JOIN albums a ON a.id = r.entity_id
                LEFT JOIN artists ar ON ar.id = a.album_artist_id
                LEFT JOIN tracks t ON t.album_id = a.id
                LEFT JOIN artists tr ON tr.id = t.artist_id
                LEFT JOIN artworks aw ON aw.id = a.artwork_id
                WHERE r.entity_type = ?
                GROUP BY a.id, r.last_opened_at
                ORDER BY r.last_opened_at DESC
                LIMIT ?
                """,
                arguments: [RecentItemType.album, limit]
            )
            let albums = albumRows.compactMap { row -> RecentAlbumSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Unknown Album"
                let albumArtist = row["album_artist_name"] as String?
                let artworkUri = row["artwork_uri"] as String?
                let isFavorite = row["is_favorite"] as Bool? ?? false
                return RecentAlbumSummary(
                    id: id,
                    name: name,
                    albumArtist: albumArtist,
                    artworkUri: artworkUri,
                    isFavorite: isFavorite
                )
            }

            let playlistRows = try Row.fetchAll(
                db,
                sql: """
                SELECT r.entity_id AS id, p.name AS name, p.is_favorite AS is_favorite
                FROM recent_items r
                JOIN playlists p ON p.id = r.entity_id
                WHERE r.entity_type = ?
                ORDER BY r.last_opened_at DESC
                LIMIT ?
                """,
                arguments: [RecentItemType.playlist, limit]
            )
            var playlists = playlistRows.compactMap { row -> RecentPlaylistSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Unknown Playlist"
                let isFavorite = row["is_favorite"] as Bool? ?? false
                return RecentPlaylistSummary(id: id, name: name, artworkUris: [], isFavorite: isFavorite)
            }
            let playlistIds = playlists.map { $0.id }
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
                playlists = playlists.map { playlist in
                    RecentPlaylistSummary(
                        id: playlist.id,
                        name: playlist.name,
                        artworkUris: artworkMap[playlist.id] ?? [],
                        isFavorite: playlist.isFavorite
                    )
                }
            }

            return (albums, playlists)
        }) ?? ([], [])
        
        return snapshot
    }
    
    private func loadRecentTracksData(appDatabase: AppDatabase, limit: Int) async -> [RecentTrackSummary] {
        let snapshot = (try? await appDatabase.dbPool.read { db -> [RecentTrackSummary] in
            let trackRows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    h.id AS id,
                    t.id AS track_id,
                    h.source AS source,
                    h.source_track_id AS source_track_id,
                    COALESCE(mo.title, t.title) AS title,
                    COALESCE(mo.artist_name, a.name) AS artist_name,
                    t.is_favorite AS is_favorite,
                    aw.file_uri AS artwork_uri
                FROM history_entries h
                LEFT JOIN tracks t
                    ON t.source = h.source AND t.source_track_id = h.source_track_id
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN artists a ON a.id = t.artist_id
                LEFT JOIN artworks aw
                    ON aw.id = COALESCE(mo.artwork_id, t.artwork_id, t.album_artwork_id)
                ORDER BY h.played_at DESC
                LIMIT ?
                """,
                arguments: [limit]
            )
            let tracks = trackRows.compactMap { row -> RecentTrackSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let sourceRaw = row["source"] as String? ?? TrackSource.local.rawValue
                let source = TrackSource(rawValue: sourceRaw) ?? .local
                let sourceTrackId = row["source_track_id"] as String? ?? ""
                let title = row["title"] as String? ?? "Unknown Title"
                let artist = row["artist_name"] as String?
                let artworkUri = row["artwork_uri"] as String?
                let isFavorite = row["is_favorite"] as Bool? ?? false
                return RecentTrackSummary(
                    id: id,
                    trackId: row["track_id"] as Int64?,
                    source: source,
                    sourceTrackId: sourceTrackId,
                    title: title,
                    artist: artist,
                    artworkUri: artworkUri,
                    isFavorite: isFavorite
                )
            }
            return tracks
        }) ?? []
        
        return snapshot
    }
    
    private func loadTopArtists(appDatabase: AppDatabase) async -> [TopArtistSummary] {
        let sinceDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let sinceDay = DateUtils.yyyymmdd(sinceDate)

        let snapshot = (try? await appDatabase.dbPool.read { db -> [TopArtistSummary] in
            let artistRows = try Row.fetchAll(
                db,
                sql: """
                SELECT a.id AS id, a.name AS name, SUM(s.play_count) AS total
                FROM listening_stats s
                JOIN artists a ON a.id = s.artist_id
                WHERE s.day >= ?
                GROUP BY a.id
                ORDER BY total DESC
                LIMIT 10
                """,
                arguments: [sinceDay]
            )
            let artists = artistRows.compactMap { row -> TopArtistSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Unknown Artist"
                return TopArtistSummary(id: id, name: name)
            }

            return artists
        }) ?? []
        
        return snapshot
    }
}
