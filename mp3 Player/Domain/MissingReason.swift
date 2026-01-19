import Foundation

enum MissingReason: String, Codable, CaseIterable {
    case notFound = "not_found"
    case permission = "permission"
    case invalidUri = "invalid_uri"

    var displayLabel: String {
        switch self {
        case .notFound:
            return "File not found"
        case .permission:
            return "Permission required"
        case .invalidUri:
            return "Invalid file reference"
        }
    }
}
