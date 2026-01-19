import Foundation
import GRDB

struct ArtworkRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var fileUri: String
    var width: Int?
    var height: Int?
    var hash: String?
    var createdAt: Int64

    static let databaseTableName = "artworks"

    enum CodingKeys: String, CodingKey {
        case id
        case fileUri = "file_uri"
        case width
        case height
        case hash
        case createdAt = "created_at"
    }
}

struct ArtistRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var name: String
    var sortName: String?
    var isFavorite: Bool = false
    var createdAt: Int64
    var updatedAt: Int64

    static let databaseTableName = "artists"

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sortName = "sort_name"
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AlbumRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var name: String
    var albumArtistId: Int64?
    var releaseYear: Int?
    var artworkId: Int64?
    var isFavorite: Bool = false
    var createdAt: Int64
    var updatedAt: Int64

    static let databaseTableName = "albums"

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case albumArtistId = "album_artist_id"
        case releaseYear = "release_year"
        case artworkId = "artwork_id"
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TrackRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var source: TrackSource
    var sourceTrackId: String
    var title: String
    var duration: Double?
    var fileUri: String?
    var contentHash: String?
    var fileSize: Int64?
    var trackNumber: Int?
    var discNumber: Int?
    var isMissing: Bool = false
    var missingReason: String?
    var isFavorite: Bool = false
    var albumId: Int64?
    var artistId: Int64?
    var albumArtistId: Int64?
    var genre: String?
    var releaseYear: Int?
    var artworkId: Int64?
    var albumArtworkId: Int64?
    var createdAt: Int64
    var updatedAt: Int64

    static let databaseTableName = "tracks"

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case sourceTrackId = "source_track_id"
        case title
        case duration
        case fileUri = "file_uri"
        case contentHash = "content_hash"
        case fileSize = "file_size"
        case trackNumber = "track_number"
        case discNumber = "disc_number"
        case isMissing = "is_missing"
        case missingReason = "missing_reason"
        case isFavorite = "is_favorite"
        case albumId = "album_id"
        case artistId = "artist_id"
        case albumArtistId = "album_artist_id"
        case genre
        case releaseYear = "release_year"
        case artworkId = "artwork_id"
        case albumArtworkId = "album_artwork_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MetadataOverrideRecord: Codable, FetchableRecord, PersistableRecord {
    var trackId: Int64
    var title: String?
    var artistName: String?
    var albumName: String?
    var genre: String?
    var releaseYear: Int?
    var artworkId: Int64?
    var albumArtworkId: Int64?
    var updatedAt: Int64

    static let databaseTableName = "metadata_overrides"

    enum CodingKeys: String, CodingKey {
        case trackId = "track_id"
        case title
        case artistName = "artist_name"
        case albumName = "album_name"
        case genre
        case releaseYear = "release_year"
        case artworkId = "artwork_id"
        case albumArtworkId = "album_artwork_id"
        case updatedAt = "updated_at"
    }
}

struct PlaylistRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var name: String
    var isFavorite: Bool = false
    var lastPlayedAt: Int64?
    var createdAt: Int64
    var updatedAt: Int64

    static let databaseTableName = "playlists"

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isFavorite = "is_favorite"
        case lastPlayedAt = "last_played_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PlaylistTrackRecord: Codable, FetchableRecord, PersistableRecord {
    var playlistId: Int64
    var trackId: Int64
    var ord: Int
    var addedAt: Int64

    static let databaseTableName = "playlist_tracks"

    enum CodingKeys: String, CodingKey {
        case playlistId = "playlist_id"
        case trackId = "track_id"
        case ord
        case addedAt = "added_at"
    }
}

struct QueueItemRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var source: TrackSource
    var sourceTrackId: String
    var ord: Int
    var addedAt: Int64

    static let databaseTableName = "queue_items"

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case sourceTrackId = "source_track_id"
        case ord
        case addedAt = "added_at"
    }
}

struct HistoryEntryRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var source: TrackSource
    var sourceTrackId: String
    var playedAt: Int64
    var position: Double

    static let databaseTableName = "history_entries"

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case sourceTrackId = "source_track_id"
        case playedAt = "played_at"
        case position
    }
}

struct RecentItemRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var entityType: RecentItemType
    var entityId: Int64
    var lastOpenedAt: Int64

    static let databaseTableName = "recent_items"

    enum CodingKeys: String, CodingKey {
        case id
        case entityType = "entity_type"
        case entityId = "entity_id"
        case lastOpenedAt = "last_opened_at"
    }
}

struct ListeningStatRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var artistId: Int64
    var day: Int
    var playCount: Int

    static let databaseTableName = "listening_stats"

    enum CodingKeys: String, CodingKey {
        case id
        case artistId = "artist_id"
        case day
        case playCount = "play_count"
    }
}

struct ImportRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var trackId: Int64?
    var originalUri: String?
    var copiedUri: String?
    var importMode: ImportMode
    var state: ImportState
    var bookmarkData: Data?
    var errorMessage: String?
    var createdAt: Int64
    var updatedAt: Int64

    static let databaseTableName = "import_records"

    enum CodingKeys: String, CodingKey {
        case id
        case trackId = "track_id"
        case originalUri = "original_uri"
        case copiedUri = "copied_uri"
        case importMode = "import_mode"
        case state
        case bookmarkData = "bookmark_data"
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PlaybackPositionRecord: Codable, FetchableRecord, PersistableRecord {
    var source: TrackSource
    var sourceTrackId: String
    var position: Double
    var updatedAt: Int64

    static let databaseTableName = "playback_positions"

    enum CodingKeys: String, CodingKey {
        case source
        case sourceTrackId = "source_track_id"
        case position
        case updatedAt = "updated_at"
    }
}

struct PlaybackStateRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var source: TrackSource
    var sourceTrackId: String
    var queueIndex: Int
    var updatedAt: Int64

    static let databaseTableName = "playback_state"

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case sourceTrackId = "source_track_id"
        case queueIndex = "queue_index"
        case updatedAt = "updated_at"
    }
}

struct LyricsRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var source: TrackSource
    var sourceTrackId: String
    var provider: String
    var content: String
    var createdAt: Int64

    static let databaseTableName = "lyrics"

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case sourceTrackId = "source_track_id"
        case provider
        case content
        case createdAt = "created_at"
    }
}
