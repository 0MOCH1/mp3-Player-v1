import Foundation
import GRDB

protocol RecentRepository {
    func touch(type: RecentItemType, entityId: Int64, at: Int64) throws
    func fetchLatest(type: RecentItemType, limit: Int) throws -> [RecentItemRecord]
    func trim(type: RecentItemType, limit: Int) throws
    func trimCombined(types: [RecentItemType], limit: Int) throws
}

final class GRDBRecentRepository: RecentRepository {
    private let dbWriter: DatabaseWriter

    init(dbWriter: DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func touch(type: RecentItemType, entityId: Int64, at: Int64) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM recent_items WHERE entity_type = ? AND entity_id = ?",
                arguments: [type, entityId]
            )

            let record = RecentItemRecord(
                id: nil,
                entityType: type,
                entityId: entityId,
                lastOpenedAt: at
            )
            try record.insert(db)

            if type == .album || type == .playlist {
                try trimCombined(types: [.album, .playlist], limit: 50, db: db)
            }
        }
    }

    func fetchLatest(type: RecentItemType, limit: Int) throws -> [RecentItemRecord] {
        try dbWriter.read { db in
            try RecentItemRecord
                .filter(Column("entity_type") == type)
                .order(Column("last_opened_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func trim(type: RecentItemType, limit: Int) throws {
        try dbWriter.write { db in
            let ids = try Row.fetchAll(
                db,
                sql: """
                SELECT id
                FROM recent_items
                WHERE entity_type = ?
                ORDER BY last_opened_at DESC
                LIMIT -1 OFFSET ?
                """,
                arguments: [type, limit]
            ).compactMap { $0["id"] as Int64? }

            if !ids.isEmpty {
                let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
                let sql = "DELETE FROM recent_items WHERE id IN (\(placeholders))"
                try db.execute(sql: sql, arguments: StatementArguments(ids))
            }
        }
    }

    func trimCombined(types: [RecentItemType], limit: Int) throws {
        try dbWriter.write { db in
            try trimCombined(types: types, limit: limit, db: db)
        }
    }

    private func trimCombined(types: [RecentItemType], limit: Int, db: Database) throws {
        guard !types.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: types.count).joined(separator: ",")
        var arguments: [DatabaseValueConvertible] = types
        arguments.append(limit)
        let ids = try Row.fetchAll(
            db,
            sql: """
            SELECT id
            FROM recent_items
            WHERE entity_type IN (\(placeholders))
            ORDER BY last_opened_at DESC
            LIMIT -1 OFFSET ?
            """,
            arguments: StatementArguments(arguments)
        ).compactMap { $0["id"] as Int64? }

        if !ids.isEmpty {
            let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
            let sql = "DELETE FROM recent_items WHERE id IN (\(placeholders))"
            try db.execute(sql: sql, arguments: StatementArguments(ids))
        }
    }
}
