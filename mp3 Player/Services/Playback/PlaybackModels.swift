import Foundation

enum PlaybackState: String {
    case stopped
    case playing
    case paused
    case buffering
}

enum RepeatMode: String, CaseIterable {
    case off
    case one
    case all
}

struct PlaybackItem: Identifiable, Equatable {
    let id: Int64
    let source: TrackSource
    let sourceTrackId: String
    let fileUri: String?
    let artworkUri: String?
    let title: String
    let artist: String?
    let album: String?
    let duration: Double?
    let artistId: Int64?
}
