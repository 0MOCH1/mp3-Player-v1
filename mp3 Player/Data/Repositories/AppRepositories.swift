import GRDB

struct AppRepositories {
    let tracks: any TrackRepository
    let trackSearch: any TrackSearchRepository
    let history: any HistoryRepository
    let playlists: any PlaylistRepository
    let queue: any QueueRepository
    let recent: any RecentRepository
    let imports: any ImportRepository
    let listeningStats: any ListeningStatsRepository
    let metadataOverrides: any MetadataOverrideRepository
    let lyrics: any LyricsRepository
    let playbackPositions: any PlaybackPositionRepository
    let playbackState: any PlaybackStateRepository

    init(dbWriter: DatabaseWriter) {
        tracks = GRDBTrackRepository(dbWriter: dbWriter)
        trackSearch = GRDBTrackSearchRepository(dbWriter: dbWriter)
        history = GRDBHistoryRepository(dbWriter: dbWriter)
        playlists = GRDBPlaylistRepository(dbWriter: dbWriter)
        queue = GRDBQueueRepository(dbWriter: dbWriter)
        recent = GRDBRecentRepository(dbWriter: dbWriter)
        imports = GRDBImportRepository(dbWriter: dbWriter)
        listeningStats = GRDBListeningStatsRepository(dbWriter: dbWriter)
        metadataOverrides = GRDBMetadataOverrideRepository(dbWriter: dbWriter)
        lyrics = GRDBLyricsRepository(dbWriter: dbWriter)
        playbackPositions = GRDBPlaybackPositionRepository(dbWriter: dbWriter)
        playbackState = GRDBPlaybackStateRepository(dbWriter: dbWriter)
    }
}
