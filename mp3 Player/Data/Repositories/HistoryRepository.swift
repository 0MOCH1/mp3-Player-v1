import GRDB

protocol HistoryRepository {
    func add(_ record: HistoryEntryRecord) throws
    func latest(limit: Int) throws -> [HistoryEntryRecord]
}

final class GRDBHistoryRepository: HistoryRepository {
    private let dbWriter: DatabaseWriter

    init(dbWriter: DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func add(_ record: HistoryEntryRecord) throws {
        try dbWriter.write { db in
            try record.insert(db)
        }
    }

    func latest(limit: Int) throws -> [HistoryEntryRecord] {
        try dbWriter.read { db in
            try HistoryEntryRecord
                .order(Column("played_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
}
