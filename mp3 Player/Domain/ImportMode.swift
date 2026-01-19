import Foundation

enum ImportMode: String, Codable, CaseIterable {
    case reference
    case copy
    case copyThenDelete = "copy_then_delete"
}
