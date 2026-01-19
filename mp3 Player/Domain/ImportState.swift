import Foundation

enum ImportState: String, Codable, CaseIterable {
    case referenced
    case copied
    case deletedOriginal = "deleted_original"
    case failed
}
