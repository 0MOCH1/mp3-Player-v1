import Combine
import Foundation

enum OperationKind: String {
    case importFiles
    case importFolder
    case rescan
}

enum OperationPhase: String {
    case preparing
    case scanning
    case importing
    case repairing
    case finishing
}

struct OperationProgress: Identifiable {
    let id: UUID
    let operation: OperationKind
    let phase: OperationPhase
    let processed: Int
    let total: Int?
    let message: String
    let startedAt: Date
    let updatedAt: Date

    var fraction: Double? {
        guard let total, total > 0 else { return nil }
        return min(max(Double(processed) / Double(total), 0), 1)
    }
}

@MainActor
final class ProgressCenter: ObservableObject {
    @Published private(set) var current: OperationProgress?
    private var lastUpdateAt: Date = .distantPast
    private let minInterval: TimeInterval = 0.2

    func update(_ progress: OperationProgress, force: Bool = false) {
        let now = Date()
        if !force && now.timeIntervalSince(lastUpdateAt) < minInterval {
            return
        }
        lastUpdateAt = now
        current = progress
    }

    func clear() {
        current = nil
    }
}
