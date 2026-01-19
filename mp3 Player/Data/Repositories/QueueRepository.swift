import Foundation
import GRDB

protocol QueueRepository {
    func enqueue(_ ref: TrackRef, position: Int?, addedAt: Int64) throws
    func fetchAll() throws -> [QueueItemRecord]
    func remove(id: Int64) throws
    func clear() throws
}

final class GRDBQueueRepository: QueueRepository {
    private let dbWriter: DatabaseWriter

    init(dbWriter: DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func enqueue(_ ref: TrackRef, position: Int?, addedAt: Int64) throws {
        try dbWriter.write { db in
            let ord: Int
            if let position {
                ord = position
            } else {
                let maxOrd: Int? = try Int.fetchOne(db, sql: "SELECT MAX(ord) FROM queue_items")
                ord = (maxOrd ?? -1) + 1
            }

            let record = QueueItemRecord(
                id: nil,
                source: ref.source,
                sourceTrackId: ref.sourceTrackId,
                ord: ord,
                addedAt: addedAt
            )
            try record.insert(db)
        }
    }

    func fetchAll() throws -> [QueueItemRecord] {
        try dbWriter.read { db in
            try QueueItemRecord
                .order(Column("ord"))
                .fetchAll(db)
        }
    }

    func remove(id: Int64) throws {
        _ = try dbWriter.write { db in
            try QueueItemRecord.deleteOne(db, key: id)
        }
    }

    func clear() throws {
        _ = try dbWriter.write { db in
            _ = try QueueItemRecord.deleteAll(db)
        }
    }
}
