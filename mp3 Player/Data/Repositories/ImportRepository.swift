import Foundation
import GRDB

protocol ImportRepository {
    func create(_ record: ImportRecord) throws
    func updateState(id: Int64, state: ImportState, updatedAt: Int64) throws
    func fetchAll() throws -> [ImportRecord]
}

final class GRDBImportRepository: ImportRepository {
    private let dbWriter: DatabaseWriter

    init(dbWriter: DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func create(_ record: ImportRecord) throws {
        try dbWriter.write { db in
            try record.insert(db)
        }
    }

    func updateState(id: Int64, state: ImportState, updatedAt: Int64) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: "UPDATE import_records SET state = ?, updated_at = ? WHERE id = ?",
                arguments: [state, updatedAt, id]
            )
        }
    }

    func fetchAll() throws -> [ImportRecord] {
        try dbWriter.read { db in
            try ImportRecord
                .order(Column("updated_at").desc)
                .fetchAll(db)
        }
    }
}
