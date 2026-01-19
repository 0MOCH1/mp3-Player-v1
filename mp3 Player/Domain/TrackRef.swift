import Foundation

struct TrackRef: Hashable, Codable {
    let source: TrackSource
    let sourceTrackId: String
}
