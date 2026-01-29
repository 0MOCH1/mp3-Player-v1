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

struct RecentPlayedItem: Identifiable {
    enum Kind {
        case album
        case playlist
    }

    let id: Int64
    let kind: Kind
    let name: String
    let albumArtist: String?
    let artworkUri: String?
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
    @Published var recentPlayedItems: [RecentPlayedItem] = []
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

    private func loadData(appDatabase: AppDatabase) async {
        let sinceDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let sinceDay = DateUtils.yyyymmdd(sinceDate)

        let snapshot = (try? await appDatabase.dbPool.read { db -> ([RecentPlayedItem], [RecentTrackSummary], [TopArtistSummary]) in
            let recentItemRows = try Row.fetchAll(
                db,
                sql: """
                SELECT entity_id, entity_type
                FROM recent_items
                WHERE entity_type IN (?, ?)
                ORDER BY last_opened_at DESC
                LIMIT 12
                """,
                arguments: [RecentItemType.album, RecentItemType.playlist]
            )
            let recentItems = recentItemRows.compactMap { row -> (id: Int64, type: RecentItemType)? in
                guard let id = row["entity_id"] as Int64? else { return nil }
                let typeRaw = row["entity_type"] as String? ?? RecentItemType.album.rawValue
                let type = RecentItemType(rawValue: typeRaw) ?? .album
                return (id, type)
            }

            let albumIds = recentItems.filter { $0.type == .album }.map { $0.id }
            let playlistIds = recentItems.filter { $0.type == .playlist }.map { $0.id }
            var albumMap: [Int64: RecentAlbumSummary] = [:]
            if !albumIds.isEmpty {
                let placeholders = albumIds.map { _ in "?" }.joined(separator: ",")
                let albumRows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT
                        a.id AS id,
                        a.name AS name,
                        COALESCE(ar.name, MIN(tr.name)) AS album_artist_name,
                        a.is_favorite AS is_favorite,
                        aw.file_uri AS artwork_uri
                    FROM albums a
                    LEFT JOIN artists ar ON ar.id = a.album_artist_id
                    LEFT JOIN tracks t ON t.album_id = a.id
                    LEFT JOIN artists tr ON tr.id = t.artist_id
                    LEFT JOIN artworks aw ON aw.id = a.artwork_id
                    WHERE a.id IN (\(placeholders))
                    GROUP BY a.id
                    """,
                    arguments: StatementArguments(albumIds)
                )
                for row in albumRows {
                    guard let id = row["id"] as Int64? else { continue }
                    let name = row["name"] as String? ?? "Unknown Album"
                    let albumArtist = row["album_artist_name"] as String?
                    let artworkUri = row["artwork_uri"] as String?
                    let isFavorite = row["is_favorite"] as Bool? ?? false
                    albumMap[id] = RecentAlbumSummary(
                        id: id,
                        name: name,
                        albumArtist: albumArtist,
                        artworkUri: artworkUri,
                        isFavorite: isFavorite
                    )
                }
            }

            var playlistMap: [Int64: RecentPlaylistSummary] = [:]
            if !playlistIds.isEmpty {
                let placeholders = playlistIds.map { _ in "?" }.joined(separator: ",")
                let playlistRows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT id, name, is_favorite
                    FROM playlists
                    WHERE id IN (\(placeholders))
                    """,
                    arguments: StatementArguments(playlistIds)
                )
                for row in playlistRows {
                    guard let id = row["id"] as Int64? else { continue }
                    let name = row["name"] as String? ?? "Unknown Playlist"
                    let isFavorite = row["is_favorite"] as Bool? ?? false
                    playlistMap[id] = RecentPlaylistSummary(id: id, name: name, artworkUris: [], isFavorite: isFavorite)
                }
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
                for (id, playlist) in playlistMap {
                    playlistMap[id] = RecentPlaylistSummary(
                        id: id,
                        name: playlist.name,
                        artworkUris: artworkMap[id] ?? [],
                        isFavorite: playlist.isFavorite
                    )
                }
            }

            let playedItems = recentItems.compactMap { item -> RecentPlayedItem? in
                switch item.type {
                case .album:
                    guard let album = albumMap[item.id] else { return nil }
                    return RecentPlayedItem(
                        id: album.id,
                        kind: .album,
                        name: album.name,
                        albumArtist: album.albumArtist,
                        artworkUri: album.artworkUri,
                        artworkUris: [],
                        isFavorite: album.isFavorite
                    )
                case .playlist:
                    guard let playlist = playlistMap[item.id] else { return nil }
                    return RecentPlayedItem(
                        id: playlist.id,
                        kind: .playlist,
                        name: playlist.name,
                        albumArtist: nil,
                        artworkUri: nil,
                        artworkUris: playlist.artworkUris,
                        isFavorite: playlist.isFavorite
                    )
                }
            }

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
                LIMIT 24
                """
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

            return (playedItems, tracks, artists)
        }) ?? ([], [], [])

        recentPlayedItems = snapshot.0
        recentTracks = snapshot.1
        topArtists = snapshot.2
    }
}
