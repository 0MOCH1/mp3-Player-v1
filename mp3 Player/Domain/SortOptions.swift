import Foundation

enum SortOrder: String, CaseIterable {
    case ascending
    case descending
}

enum TrackSortField: String, CaseIterable {
    case title
    case addedDate
    case artist
}

enum AlbumSortField: String, CaseIterable {
    case title
    case addedDate
    case artist
    case releaseYear
}

enum PlaylistSortField: String, CaseIterable {
    case title
    case createdDate
    case lastPlayedDate
    case updatedDate
}

enum PlaylistTrackSortField: String, CaseIterable {
    case manual
    case title
    case artist
    case album
    case releaseYear
    case addedDate
}
