import GRDB

protocol MetadataOverrideRepository {
    func upsert(_ record: MetadataOverrideRecord) throws
    func delete(trackId: Int64) throws
}

final class GRDBMetadataOverrideRepository: MetadataOverrideRepository {
    private let dbWriter: DatabaseWriter

    init(dbWriter: DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func upsert(_ record: MetadataOverrideRecord) throws {
        try dbWriter.write { db in
            try record.save(db)
            try TrackIndexing.reindex(trackId: record.trackId, db: db)
        }
    }

    func delete(trackId: Int64) throws {
        try dbWriter.write { db in
            try MetadataOverrideRecord.deleteOne(db, key: trackId)
            try TrackIndexing.reindex(trackId: trackId, db: db)
        }
    }
}
