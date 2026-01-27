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

/// キューに追加された元の種別
enum QueueSourceType: String, Equatable {
    case album
    case playlist
    case artist
    case search
    case unknown
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
    
    /// キューに追加された元の名前（アルバム名、プレイリスト名など）
    var queueSourceName: String?
    /// キューに追加された元の種別
    var queueSourceType: QueueSourceType = .unknown
    
    /// ソースラベル表示用（例: "From: Album 1" または "From: My Playlist"）
    var sourceLabel: String? {
        guard let name = queueSourceName else {
            // フォールバック：アルバム名を使用
            return album
        }
        return name
    }
}
