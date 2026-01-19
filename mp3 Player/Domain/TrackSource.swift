import Foundation

enum TrackSource: String, Codable, CaseIterable {
    case local
    case musicKit
    case streaming
    case url
}
