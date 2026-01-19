import Combine
import Foundation
import GRDB
import MusicKit

enum SearchScope: String, CaseIterable {
    case local
    case external
}

struct SearchArtistResult: Identifiable {
    let id: Int64
    let name: String
}

struct SearchAlbumResult: Identifiable {
    let id: Int64
    let name: String
    let albumArtist: String?
    let releaseYear: Int?
    let artworkUri: String?
    let isFavorite: Bool
}

struct SearchTrackResult: Identifiable {
    let id: Int64
    let title: String
    let artist: String?
    let album: String?
    let isFavorite: Bool
    let artworkUri: String?
}

struct SearchPlaylistResult: Identifiable {
    let id: Int64
    let name: String
    let isFavorite: Bool
    let artworkUris: [String?]
}

struct SearchLyricsResult: Identifiable {
    let id: Int64
    let title: String
    let artist: String?
    let artworkUri: String?
}

struct SearchExternalArtistResult: Identifiable {
    let id: String
    let name: String
}

struct SearchExternalAlbumResult: Identifiable {
    let id: String
    let name: String
    let artist: String?
    let releaseYear: Int?
}

struct SearchExternalTrackResult: Identifiable {
    let id: String
    let title: String
    let artist: String?
    let album: String?
}

struct SearchExternalPlaylistResult: Identifiable {
    let id: String
    let name: String
    let curator: String?
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var artists: [SearchArtistResult] = []
    @Published var albums: [SearchAlbumResult] = []
    @Published var tracks: [SearchTrackResult] = []
    @Published var playlists: [SearchPlaylistResult] = []
    @Published var lyrics: [SearchLyricsResult] = []
    @Published var externalStatusMessage = "Apple Music not available."
    @Published var externalCanRequest = false
    @Published var externalIsAuthorized = false
    @Published var externalIsRequesting = false
    @Published var externalArtists: [SearchExternalArtistResult] = []
    @Published var externalAlbums: [SearchExternalAlbumResult] = []
    @Published var externalTracks: [SearchExternalTrackResult] = []
    @Published var externalPlaylists: [SearchExternalPlaylistResult] = []

    private var searchTask: Task<Void, Never>?

    func updateQuery(
        _ query: String,
        scope: SearchScope,
        appDatabase: AppDatabase?,
        appleMusicService: (any AppleMusicService)?
    ) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        updateExternalState(appleMusicService)

        guard scope == .local else {
            clearResults()
            if trimmed.isEmpty {
                externalStatusMessage = externalIsAuthorized
                    ? "Type to search Apple Music."
                    : externalStatusMessage
                clearExternalResults()
                return
            }
            guard externalIsAuthorized else {
                clearExternalResults()
                return
            }

            searchTask = Task {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                await performExternalSearch(query: trimmed)
            }
            return
        }

        guard let appDatabase else {
            clearResults()
            return
        }

        if trimmed.isEmpty {
            clearResults()
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            let lyricQuery = Self.lyricsMatchQuery(trimmed)
            let results = (try? await appDatabase.dbPool.read { db -> (artists: [SearchArtistResult], albums: [SearchAlbumResult], tracks: [SearchTrackResult], playlists: [SearchPlaylistResult], lyrics: [SearchLyricsResult]) in
                let likePattern = "%\(trimmed)%"

                let artistRows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT id, name
                    FROM artists
                    WHERE name LIKE ? COLLATE NOCASE
                    ORDER BY name COLLATE NOCASE
                    LIMIT 50
                    """,
                    arguments: [likePattern]
                )
                let artistResults = artistRows.compactMap { row -> SearchArtistResult? in
                    guard let id = row["id"] as Int64? else { return nil }
                    let name = row["name"] as String? ?? "Unknown Artist"
                    return SearchArtistResult(id: id, name: name)
                }

                let albumRows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT
                        al.id AS id,
                        al.name AS name,
                        COALESCE(ar.name, MIN(tr.name)) AS album_artist_name,
                        al.release_year AS release_year,
                        al.is_favorite AS is_favorite,
                        aw.file_uri AS artwork_uri
                    FROM albums al
                    LEFT JOIN artists ar ON ar.id = al.album_artist_id
                    LEFT JOIN tracks t ON t.album_id = al.id
                    LEFT JOIN artists tr ON tr.id = t.artist_id
                    LEFT JOIN artworks aw ON aw.id = al.artwork_id
                    WHERE al.name LIKE ? COLLATE NOCASE
                    GROUP BY al.id
                    ORDER BY al.name COLLATE NOCASE
                    LIMIT 50
                    """,
                    arguments: [likePattern]
                )
                let albumResults = albumRows.compactMap { row -> SearchAlbumResult? in
                    guard let id = row["id"] as Int64? else { return nil }
                    let name = row["name"] as String? ?? "Unknown Album"
                    let albumArtist = row["album_artist_name"] as String?
                    let releaseYear = row["release_year"] as Int?
                    let isFavorite = row["is_favorite"] as Bool? ?? false
                    let artworkUri = row["artwork_uri"] as String?
                    return SearchAlbumResult(
                        id: id,
                        name: name,
                        albumArtist: albumArtist,
                        releaseYear: releaseYear,
                        artworkUri: artworkUri,
                        isFavorite: isFavorite
                    )
                }

                let trackResults: [SearchTrackResult]
                if let pattern = FTS5Pattern(matchingAnyTokenIn: trimmed) {
                    let trackRows = try Row.fetchAll(
                        db,
                        sql: """
                        WITH matched AS (
                            SELECT track_id, bm25(tracks_fts) AS score
                            FROM tracks_fts
                            WHERE tracks_fts MATCH ?
                            ORDER BY score
                            LIMIT 50
                        )
                        SELECT
                            t.id AS id,
                            COALESCE(mo.title, t.title) AS title,
                            COALESCE(mo.artist_name, ar.name) AS artist_name,
                            COALESCE(mo.album_name, al.name) AS album_name,
                            t.is_favorite AS is_favorite,
                            aw.file_uri AS artwork_uri,
                            m.score AS score
                        FROM matched m
                        JOIN tracks t ON t.id = m.track_id
                        LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                        LEFT JOIN artists ar ON ar.id = t.artist_id
                        LEFT JOIN albums al ON al.id = t.album_id
                        LEFT JOIN artworks aw
                            ON aw.id = COALESCE(mo.artwork_id, t.artwork_id, t.album_artwork_id)
                        ORDER BY m.score
                        """,
                        arguments: [pattern]
                    )
                    trackResults = trackRows.compactMap { row -> SearchTrackResult? in
                        guard let id = row["id"] as Int64? else { return nil }
                        let title = row["title"] as String? ?? "Unknown Title"
                        let artist = row["artist_name"] as String?
                        let album = row["album_name"] as String?
                        let isFavorite = row["is_favorite"] as Bool? ?? false
                        let artworkUri = row["artwork_uri"] as String?
                        return SearchTrackResult(
                            id: id,
                            title: title,
                            artist: artist,
                            album: album,
                            isFavorite: isFavorite,
                            artworkUri: artworkUri
                        )
                    }
                } else {
                    trackResults = []
                }

                let playlistRows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT id, name, is_favorite
                    FROM playlists
                    WHERE name LIKE ? COLLATE NOCASE
                    ORDER BY name COLLATE NOCASE
                    LIMIT 50
                    """,
                    arguments: [likePattern]
                )
                var playlistResults = playlistRows.compactMap { row -> SearchPlaylistResult? in
                    guard let id = row["id"] as Int64? else { return nil }
                    let name = row["name"] as String? ?? "Untitled Playlist"
                    let isFavorite = row["is_favorite"] as Bool? ?? false
                    return SearchPlaylistResult(id: id, name: name, isFavorite: isFavorite, artworkUris: [])
                }
                let playlistIds = playlistResults.map { $0.id }
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
                    playlistResults = playlistResults.map { playlist in
                        SearchPlaylistResult(
                            id: playlist.id,
                            name: playlist.name,
                            isFavorite: playlist.isFavorite,
                            artworkUris: artworkMap[playlist.id] ?? []
                        )
                    }
                }

                let lyricResults: [SearchLyricsResult]
                if !lyricQuery.isEmpty {
                    let lyricRows = try Row.fetchAll(
                        db,
                        sql: """
                        WITH matched AS (
                            SELECT track_id, bm25(tracks_fts) AS score
                            FROM tracks_fts
                            WHERE tracks_fts MATCH ?
                              AND lyrics IS NOT NULL
                            ORDER BY score
                            LIMIT 50
                        )
                        SELECT
                            t.id AS id,
                            COALESCE(mo.title, t.title) AS title,
                            COALESCE(mo.artist_name, ar.name) AS artist_name,
                            aw.file_uri AS artwork_uri
                        FROM matched m
                        JOIN tracks t ON t.id = m.track_id
                        LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                        LEFT JOIN artists ar ON ar.id = t.artist_id
                        LEFT JOIN artworks aw
                            ON aw.id = COALESCE(mo.artwork_id, t.artwork_id, t.album_artwork_id)
                        ORDER BY m.score
                        """,
                        arguments: [lyricQuery]
                    )
                    lyricResults = lyricRows.compactMap { row -> SearchLyricsResult? in
                        guard let id = row["id"] as Int64? else { return nil }
                        let title = row["title"] as String? ?? "Unknown Title"
                        let artist = row["artist_name"] as String?
                        let artworkUri = row["artwork_uri"] as String?
                        return SearchLyricsResult(id: id, title: title, artist: artist, artworkUri: artworkUri)
                    }
                } else {
                    lyricResults = []
                }

                return (artistResults, albumResults, trackResults, playlistResults, lyricResults)
            }) ?? ([], [], [], [], [])

            guard !Task.isCancelled else { return }
            let (artistResults, albumResults, trackResults, playlistResults, lyricResults) = results
            artists = artistResults
            albums = albumResults
            tracks = trackResults
            playlists = playlistResults
            lyrics = lyricResults
        }
    }

    private func clearResults() {
        artists = []
        albums = []
        tracks = []
        playlists = []
        lyrics = []
    }

    private func clearExternalResults() {
        externalArtists = []
        externalAlbums = []
        externalTracks = []
        externalPlaylists = []
    }

    private func updateExternalState(_ appleMusicService: (any AppleMusicService)?) {
        guard let appleMusicService else {
            externalStatusMessage = "Apple Music service unavailable."
            externalCanRequest = false
            externalIsAuthorized = false
            return
        }

        let status = appleMusicService.authorizationStatus()
        externalCanRequest = status.canRequestAccess
        externalIsAuthorized = status.isAuthorized

        switch status {
        case .authorized:
            externalStatusMessage = "Apple Music access granted."
        case .notDetermined:
            externalStatusMessage = "Apple Music access not requested."
        case .denied:
            externalStatusMessage = "Apple Music access denied. Enable in Settings."
        case .restricted:
            externalStatusMessage = "Apple Music access restricted."
        case .unknown:
            externalStatusMessage = "Apple Music access unavailable."
        }
    }

    func requestExternalAuthorization(_ appleMusicService: (any AppleMusicService)?) {
        guard let appleMusicService else { return }
        guard !externalIsRequesting else { return }
        externalIsRequesting = true
        Task {
            let status = await appleMusicService.requestAuthorization()
            externalIsRequesting = false
            externalCanRequest = status.canRequestAccess
            externalIsAuthorized = status.isAuthorized
            switch status {
            case .authorized:
                externalStatusMessage = "Apple Music access granted."
            case .notDetermined:
                externalStatusMessage = "Apple Music access not requested."
            case .denied:
                externalStatusMessage = "Apple Music access denied. Enable in Settings."
            case .restricted:
                externalStatusMessage = "Apple Music access restricted."
            case .unknown:
                externalStatusMessage = "Apple Music access unavailable."
            }
        }
    }

    private static func lyricsMatchQuery(_ query: String) -> String {
        let tokens = query.split(whereSeparator: { $0.isWhitespace })
        guard !tokens.isEmpty else { return "" }
        return tokens.map { "lyrics:\($0)" }.joined(separator: " OR ")
    }

    private func performExternalSearch(query: String) async {
        var request = MusicCatalogSearchRequest(
            term: query,
            types: [Artist.self, Album.self, Song.self, Playlist.self]
        )
        request.limit = 25

        do {
            let response = try await request.response()
            let artistResults = response.artists.map {
                SearchExternalArtistResult(id: $0.id.rawValue, name: $0.name)
            }
            let albumResults = response.albums.map { album in
                SearchExternalAlbumResult(
                    id: album.id.rawValue,
                    name: album.title,
                    artist: album.artistName,
                    releaseYear: album.releaseDate.map { Calendar.current.component(.year, from: $0) }
                )
            }
            let trackResults = response.songs.map { song in
                SearchExternalTrackResult(
                    id: song.id.rawValue,
                    title: song.title,
                    artist: song.artistName,
                    album: song.albumTitle
                )
            }
            let playlistResults = response.playlists.map { playlist in
                SearchExternalPlaylistResult(
                    id: playlist.id.rawValue,
                    name: playlist.name,
                    curator: playlist.curatorName
                )
            }

            externalArtists = artistResults
            externalAlbums = albumResults
            externalTracks = trackResults
            externalPlaylists = playlistResults
            externalStatusMessage = "Apple Music results loaded."
        } catch {
            clearExternalResults()
            externalStatusMessage = "Apple Music search failed."
        }
    }
}
