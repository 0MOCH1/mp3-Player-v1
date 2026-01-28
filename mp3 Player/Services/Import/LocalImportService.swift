import CryptoKit
import Foundation
import GRDB
import UniformTypeIdentifiers

enum LocalImportError: LocalizedError {
    case unsupportedURL
    case copyVerificationFailed(expected: Int64, actual: Int64)

    var errorDescription: String? {
        switch self {
        case .unsupportedURL:
            return "Unsupported file URL."
        case .copyVerificationFailed(let expected, let actual):
            return "Copy verification failed (expected \(expected) bytes, got \(actual) bytes)."
        }
    }
}

private struct ArtworkPayload {
    let hash: String
    let width: Int?
    let height: Int?
    let fileUri: String
}

nonisolated private func artworkFileExists(_ uri: String?, fileManager: FileManager) -> Bool {
    guard let uri,
          let url = URL(string: uri),
          url.isFileURL else {
        return false
    }
    return fileManager.fileExists(atPath: url.path)
}

nonisolated private func hashArtworkData(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

nonisolated private func prepareArtworkPayload(
    data: Data?,
    baseDirectory: URL,
    fileManager: FileManager
) throws -> ArtworkPayload? {
    guard let data, !data.isEmpty else { return nil }
    let hash = hashArtworkData(data)
    let (width, height) = ArtworkStorage.imageSize(for: data)
    let fileURL = try ArtworkStorage.storeArtwork(
        data: data,
        hash: hash,
        baseDirectory: baseDirectory,
        fileManager: fileManager
    )
    return ArtworkPayload(
        hash: hash,
        width: width,
        height: height,
        fileUri: fileURL.absoluteString
    )
}

nonisolated private func upsertArtworkId(
    payload: ArtworkPayload?,
    now: Int64,
    db: Database
) throws -> Int64? {
    guard let payload else { return nil }
    if let row = try Row.fetchOne(
        db,
        sql: "SELECT id, file_uri, width, height FROM artworks WHERE hash = ?",
        arguments: [payload.hash]
    ) {
        let existingId: Int64 = row["id"]
        let existingUri: String? = row["file_uri"]
        let existingWidth: Int? = row["width"]
        let existingHeight: Int? = row["height"]
        let fileExists = artworkFileExists(existingUri, fileManager: .default)
        let needsFileUpdate = !fileExists || existingUri != payload.fileUri
        let needsSizeUpdate = (existingWidth == nil && payload.width != nil)
            || (existingHeight == nil && payload.height != nil)

        if needsFileUpdate || needsSizeUpdate {
            try db.execute(
                sql: """
                UPDATE artworks
                SET file_uri = ?,
                    width = COALESCE(width, ?),
                    height = COALESCE(height, ?)
                WHERE id = ?
                """,
                arguments: [payload.fileUri, payload.width, payload.height, existingId]
            )
        }

        return existingId
    }

    let record = ArtworkRecord(
        id: nil,
        fileUri: payload.fileUri,
        width: payload.width,
        height: payload.height,
        hash: payload.hash,
        createdAt: now
    )
    try record.insert(db)
    return record.id ?? db.lastInsertedRowID
}

final class LocalImportService: @unchecked Sendable {
    private let appDatabase: AppDatabase
    private let metadataReader: AudioMetadataReader
    private let fileManager: FileManager

    init(
        appDatabase: AppDatabase,
        metadataReader: AudioMetadataReader = AVAssetMetadataReader(),
        fileManager: FileManager = .default
    ) {
        self.appDatabase = appDatabase
        self.metadataReader = metadataReader
        self.fileManager = fileManager
    }

    struct ImportResult {
        let trackId: Int64
        let outcome: ImportOutcome
    }

    enum ImportOutcome {
        case imported
        case skippedDuplicate
        case relinkedExisting
    }

    func importFile(
        from url: URL,
        mode: ImportMode,
        allowDeleteOriginal: Bool = false
    ) async throws -> ImportResult {
        guard url.isFileURL else {
            throw LocalImportError.unsupportedURL
        }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let originalUri = url.absoluteString
        let bookmarkData: Data? = (mode == .reference)
            ? (try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil))
            : nil

        let now = Int64(Date().timeIntervalSince1970)
        let baseDirectory = AppDatabase.defaultDirectory
        
        // Compute fingerprint with error logging
        let fingerprint: FileFingerprint?
        do {
            fingerprint = try computeFingerprint(for: url)
        } catch {
            LogHelper.logWarning("Failed to compute fingerprint for \(url.lastPathComponent)", context: "Import")
            fingerprint = nil
        }
        
        let metadata = try await metadataReader.read(from: url)
        let lyricsContent = cleanedLyrics(metadata.lyrics)
        if let fingerprint,
           let duplicate = try await findDuplicateTrack(hash: fingerprint.hash),
           let duplicateId = duplicate.id,
           isLikelyDuplicate(existing: duplicate, fingerprint: fingerprint, metadataDuration: metadata.duration) {
            let needsRelink = shouldRelinkDuplicate(duplicate)
            if needsRelink {
                try await relinkDuplicate(
                    trackId: duplicateId,
                    originalURL: url,
                    originalUri: originalUri,
                    mode: mode,
                    bookmarkData: bookmarkData,
                    fingerprint: fingerprint
                )
                return ImportResult(trackId: duplicateId, outcome: .relinkedExisting)
            }

            let needsArtwork = await needsArtworkBackfill(for: duplicate)
            if needsArtwork,
               let artworkData = metadata.artworkData {
                try? await backfillArtwork(
                    track: duplicate,
                    artworkData: artworkData,
                    now: now,
                    baseDirectory: baseDirectory
                )
            }
            if let lyrics = lyricsContent {
                await backfillLyricsIfNeeded(
                    trackId: duplicateId,
                    source: duplicate.source,
                    sourceTrackId: duplicate.sourceTrackId,
                    content: lyrics,
                    now: now
                )
            }
            return ImportResult(trackId: duplicateId, outcome: .skippedDuplicate)
        }

        let copiedUri: String?
        let fileUri: String?
        let sourceTrackId: String
        switch mode {
        case .reference:
            copiedUri = nil
            fileUri = originalUri
            sourceTrackId = originalUri
        case .copy, .copyThenDelete:
            let destination = try copyToLibrary(from: url, expectedSize: fingerprint?.fileSize)
            let destinationUri = destination.absoluteString
            copiedUri = destinationUri
            fileUri = destinationUri
            sourceTrackId = destinationUri
        }

        if mode == .copyThenDelete && allowDeleteOriginal {
            try? fileManager.removeItem(at: url)
        }

        let title = cleaned(metadata.title) ?? url.deletingPathExtension().lastPathComponent
        let artistName = cleaned(metadata.artist)
        let albumArtistName = cleaned(metadata.albumArtist) ?? artistName
        let albumName = cleaned(metadata.album)
        let genre = cleaned(metadata.genre)

        let artworkPayload = try? prepareArtworkPayload(
            data: metadata.artworkData,
            baseDirectory: baseDirectory,
            fileManager: fileManager
        )

        let trackId = try await appDatabase.dbPool.write { db in
            func upsertTrack(_ record: TrackRecord) throws -> Int64 {
                try db.execute(
                    sql: """
                    INSERT INTO tracks (
                        id,
                        source,
                        source_track_id,
                        title,
                        duration,
                        file_uri,
                        content_hash,
                        file_size,
                        track_number,
                        disc_number,
                        is_missing,
                        missing_reason,
                        is_favorite,
                        album_id,
                        artist_id,
                        album_artist_id,
                        genre,
                        release_year,
                        artwork_id,
                        album_artwork_id,
                        created_at,
                        updated_at
                    ) VALUES (
                        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
                    )
                    ON CONFLICT(source, source_track_id)
                    DO UPDATE SET
                        title = excluded.title,
                        duration = excluded.duration,
                        file_uri = excluded.file_uri,
                        content_hash = excluded.content_hash,
                        file_size = excluded.file_size,
                        track_number = excluded.track_number,
                        disc_number = excluded.disc_number,
                        is_missing = excluded.is_missing,
                        missing_reason = NULL,
                        is_favorite = excluded.is_favorite,
                        album_id = excluded.album_id,
                        artist_id = excluded.artist_id,
                        album_artist_id = excluded.album_artist_id,
                        genre = excluded.genre,
                        release_year = excluded.release_year,
                        artwork_id = excluded.artwork_id,
                        album_artwork_id = excluded.album_artwork_id,
                        updated_at = excluded.updated_at
                    """,
                    arguments: [
                        record.id,
                        record.source,
                        record.sourceTrackId,
                        record.title,
                        record.duration,
                        record.fileUri,
                        record.contentHash,
                        record.fileSize,
                        record.trackNumber,
                        record.discNumber,
                        record.isMissing,
                        record.missingReason,
                        record.isFavorite,
                        record.albumId,
                        record.artistId,
                        record.albumArtistId,
                        record.genre,
                        record.releaseYear,
                        record.artworkId,
                        record.albumArtworkId,
                        record.createdAt,
                        record.updatedAt,
                    ]
                )

                guard let trackId = try Int64.fetchOne(
                    db,
                    sql: "SELECT id FROM tracks WHERE source = ? AND source_track_id = ?",
                    arguments: [record.source, record.sourceTrackId]
                ) else {
                    throw DatabaseError(message: "Missing track id after upsert.")
                }

                try TrackIndexing.reindex(trackId: trackId, db: db)
                return trackId
            }

            let artworkId = try upsertArtworkId(
                payload: artworkPayload,
                now: now,
                db: db
            )
            let artistId = try self.upsertArtistId(name: artistName, now: now, db: db)
            let albumArtistId = try self.upsertArtistId(name: albumArtistName, now: now, db: db) ?? artistId
            let albumId = try self.upsertAlbumId(
                name: albumName,
                albumArtistId: albumArtistId,
                releaseYear: metadata.releaseYear,
                artworkId: artworkId,
                now: now,
                db: db
            )
            let albumArtworkId = try albumId.flatMap { id in
                try Int64.fetchOne(
                    db,
                    sql: "SELECT artwork_id FROM albums WHERE id = ?",
                    arguments: [id]
                )
            }

            let record = TrackRecord(
                id: nil,
                source: .local,
                sourceTrackId: sourceTrackId,
                title: title,
                duration: metadata.duration,
                fileUri: fileUri,
                contentHash: fingerprint?.hash,
                fileSize: fingerprint?.fileSize,
                trackNumber: metadata.trackNumber,
                discNumber: metadata.discNumber,
                isMissing: false,
                missingReason: nil,
                isFavorite: false,
                albumId: albumId,
                artistId: artistId,
                albumArtistId: albumArtistId,
                genre: genre,
                releaseYear: metadata.releaseYear,
                artworkId: artworkId,
                albumArtworkId: albumArtworkId ?? artworkId,
                createdAt: now,
                updatedAt: now
            )

            let trackId = try upsertTrack(record)

            if let lyrics = lyricsContent {
                let record = LyricsRecord(
                    id: nil,
                    source: .local,
                    sourceTrackId: sourceTrackId,
                    provider: LyricsProvider.embedded.rawValue,
                    content: lyrics,
                    createdAt: now
                )
                try? record.save(db)
                try? TrackIndexing.reindex(trackId: trackId, db: db)
            }

            let state: ImportState
            switch mode {
            case .reference:
                state = .referenced
            case .copy:
                state = .copied
            case .copyThenDelete:
                state = allowDeleteOriginal ? .deletedOriginal : .copied
            }

            let importRecord = ImportRecord(
                id: nil,
                trackId: trackId,
                originalUri: originalUri,
                copiedUri: copiedUri,
                importMode: mode,
                state: state,
                bookmarkData: bookmarkData,
                errorMessage: nil,
                createdAt: now,
                updatedAt: now
            )
            try importRecord.insert(db)

            try db.execute(
                sql: """
                DELETE FROM import_records
                WHERE original_uri = ? AND import_mode = ? AND state = ?
                """,
                arguments: [originalUri, mode, ImportState.failed]
            )

            return trackId
        }

        return ImportResult(trackId: trackId, outcome: .imported)
    }

    private struct FileFingerprint {
        let hash: String
        let fileSize: Int64
    }

    private func backfillArtwork(
        track: TrackRecord,
        artworkData: Data?,
        now: Int64,
        baseDirectory: URL
    ) async throws {
        guard let trackId = track.id else { return }
        let artworkPayload = try? prepareArtworkPayload(
            data: artworkData,
            baseDirectory: baseDirectory,
            fileManager: fileManager
        )
        guard let artworkPayload else { return }
        let existingRow = try? appDatabase.dbPool.read { db -> Row? in
            try Row.fetchOne(
                db,
                sql: """
                SELECT ta.file_uri AS track_artwork_uri,
                       aa.file_uri AS album_artwork_uri
                FROM tracks t
                LEFT JOIN artworks ta ON ta.id = t.artwork_id
                LEFT JOIN artworks aa ON aa.id = t.album_artwork_id
                WHERE t.id = ?
                """,
                arguments: [trackId]
            )
        }
        let trackArtworkUri: String? = existingRow?["track_artwork_uri"]
        let albumArtworkUri: String? = existingRow?["album_artwork_uri"]
        let hasTrackArtwork = artworkFileExists(trackArtworkUri, fileManager: fileManager)
        let hasAlbumArtwork = artworkFileExists(albumArtworkUri, fileManager: fileManager)
        let shouldUpdateTrackArtwork = track.artworkId == nil || !hasTrackArtwork
        let shouldUpdateAlbumArtwork = track.albumArtworkId == nil || !hasAlbumArtwork

        try await appDatabase.dbPool.write { db in
            let artworkId = try upsertArtworkId(
                payload: artworkPayload,
                now: now,
                db: db
            )
            guard let artworkId else { return }

            if shouldUpdateTrackArtwork {
                try db.execute(
                    sql: "UPDATE tracks SET artwork_id = ?, updated_at = ? WHERE id = ?",
                    arguments: [artworkId, now, trackId]
                )
            }
            if shouldUpdateAlbumArtwork {
                try db.execute(
                    sql: "UPDATE tracks SET album_artwork_id = ?, updated_at = ? WHERE id = ?",
                    arguments: [artworkId, now, trackId]
                )
            }
            if let albumId = track.albumId, shouldUpdateAlbumArtwork {
                try db.execute(
                    sql: """
                    UPDATE albums
                    SET artwork_id = COALESCE(artwork_id, ?),
                        updated_at = CASE WHEN artwork_id IS NULL THEN ? ELSE updated_at END
                    WHERE id = ?
                    """,
                    arguments: [artworkId, now, albumId]
                )
            }
        }
    }

    private func needsArtworkBackfill(for track: TrackRecord) async -> Bool {
        guard let trackId = track.id else { return true }
        if track.artworkId == nil && track.albumArtworkId == nil {
            return true
        }

        let row = try? appDatabase.dbPool.read { db -> Row? in
            try Row.fetchOne(
                db,
                sql: """
                SELECT ta.file_uri AS track_artwork_uri,
                       aa.file_uri AS album_artwork_uri
                FROM tracks t
                LEFT JOIN artworks ta ON ta.id = t.artwork_id
                LEFT JOIN artworks aa ON aa.id = t.album_artwork_id
                WHERE t.id = ?
                """,
                arguments: [trackId]
            )
        }
        guard let row else { return true }

        let trackArtworkUri: String? = row["track_artwork_uri"]
        let albumArtworkUri: String? = row["album_artwork_uri"]
        let hasTrackArtwork = artworkFileExists(trackArtworkUri, fileManager: fileManager)
        let hasAlbumArtwork = artworkFileExists(albumArtworkUri, fileManager: fileManager)
        return !hasTrackArtwork && !hasAlbumArtwork
    }

    private func computeFingerprint(for url: URL) throws -> FileFingerprint {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let sizeNumber = attributes[.size] as? NSNumber
        let size = sizeNumber?.uint64Value ?? 0

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let chunkSize = 64 * 1024
        let head = try handle.read(upToCount: chunkSize) ?? Data()

        let tailOffset = size > UInt64(chunkSize) ? size - UInt64(chunkSize) : 0
        try handle.seek(toOffset: tailOffset)
        let tail = try handle.read(upToCount: chunkSize) ?? Data()

        var hasher = SHA256()
        var sizeValue = size.bigEndian
        withUnsafeBytes(of: &sizeValue) { buffer in
            hasher.update(data: Data(buffer))
        }
        hasher.update(data: head)
        hasher.update(data: tail)
        let digest = hasher.finalize()
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return FileFingerprint(hash: hash, fileSize: Int64(size))
    }

    private func isLikelyDuplicate(
        existing: TrackRecord,
        fingerprint: FileFingerprint,
        metadataDuration: Double?
    ) -> Bool {
        if let existingSize = existing.fileSize, existingSize != fingerprint.fileSize {
            return false
        }
        if existing.fileSize == nil {
            return false
        }
        if let existingDuration = existing.duration {
            guard let metadataDuration else { return false }
            if abs(existingDuration - metadataDuration) > 1.0 {
                return false
            }
        }
        return true
    }

    private func backfillLyricsIfNeeded(
        trackId: Int64,
        source: TrackSource,
        sourceTrackId: String,
        content: String,
        now: Int64
    ) async {
        let hasLyrics = (try? await appDatabase.dbPool.read { db -> Bool in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT 1
                FROM lyrics
                WHERE source = ? AND source_track_id = ? AND provider = ?
                LIMIT 1
                """,
                arguments: [source, sourceTrackId, LyricsProvider.embedded.rawValue]
            )
            return row != nil
        }) ?? false

        guard !hasLyrics else { return }

        try? await appDatabase.dbPool.write { db in
            let record = LyricsRecord(
                id: nil,
                source: source,
                sourceTrackId: sourceTrackId,
                provider: LyricsProvider.embedded.rawValue,
                content: content,
                createdAt: now
            )
            try record.save(db)
            try TrackIndexing.reindex(trackId: trackId, db: db)
        }
    }

    private func findDuplicateTrack(hash: String) async throws -> TrackRecord? {
        try await appDatabase.dbPool.read { db in
            try TrackRecord
                .filter(Column("source") == TrackSource.local && Column("content_hash") == hash)
                .fetchOne(db)
        }
    }

    private func shouldRelinkDuplicate(_ record: TrackRecord) -> Bool {
        if record.isMissing {
            return true
        }
        guard let fileUri = record.fileUri,
              let url = URL(string: fileUri),
              url.isFileURL else {
            return true
        }
        return !fileManager.fileExists(atPath: url.path)
    }

    private func relinkDuplicate(
        trackId: Int64,
        originalURL: URL,
        originalUri: String,
        mode: ImportMode,
        bookmarkData: Data?,
        fingerprint: FileFingerprint
    ) async throws {
        let copiedUri: String?
        let fileUri: String
        let state: ImportState
        let recordBookmark: Data?

        switch mode {
        case .reference:
            copiedUri = nil
            fileUri = originalUri
            state = .referenced
            recordBookmark = bookmarkData
        case .copy, .copyThenDelete:
            let destination = try copyToLibrary(from: originalURL, expectedSize: fingerprint.fileSize)
            copiedUri = destination.absoluteString
            fileUri = copiedUri ?? originalUri
            state = .copied
            recordBookmark = nil
        }

        let now = Int64(Date().timeIntervalSince1970)
        try await appDatabase.dbPool.write { db in
            try db.execute(
                sql: """
                UPDATE tracks
                SET file_uri = ?,
                    content_hash = ?,
                    file_size = ?,
                    is_missing = 0,
                    missing_reason = NULL,
                    updated_at = ?
                WHERE id = ?
                """,
                arguments: [fileUri, fingerprint.hash, fingerprint.fileSize, now, trackId]
            )

            let importRecord = ImportRecord(
                id: nil,
                trackId: trackId,
                originalUri: originalUri,
                copiedUri: copiedUri,
                importMode: mode,
                state: state,
                bookmarkData: recordBookmark,
                errorMessage: nil,
                createdAt: now,
                updatedAt: now
            )
            try importRecord.insert(db)
        }
    }

    struct ImportBatchResult {
        let importedCount: Int
        let relinkedCount: Int
        let skippedCount: Int
        let failures: [String]
    }

    private struct FailedImportEntry {
        let id: Int64
        let originalUri: String
        let importMode: ImportMode
        let bookmarkData: Data?
    }

    private func errorMessage(from error: Error) -> String {
        if let error = error as? LocalImportError {
            return error.localizedDescription
        }
        return (error as NSError).localizedDescription
    }

    private func recordFailedImport(url: URL, mode: ImportMode, error: Error) async {
        let originalUri = url.absoluteString
        let now = Int64(Date().timeIntervalSince1970)
        let message = errorMessage(from: error)
        let bookmarkData: Data? = {
            guard url.isFileURL else { return nil }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        }()

        try? await appDatabase.dbPool.write { db in
            if let existingId = try Int64.fetchOne(
                db,
                sql: """
                SELECT id
                FROM import_records
                WHERE original_uri = ? AND import_mode = ? AND state = ?
                """,
                arguments: [originalUri, mode, ImportState.failed]
            ) {
                try db.execute(
                    sql: """
                    UPDATE import_records
                    SET error_message = ?,
                        bookmark_data = COALESCE(?, bookmark_data),
                        updated_at = ?
                    WHERE id = ?
                    """,
                    arguments: [message, bookmarkData, now, existingId]
                )
            } else {
                let record = ImportRecord(
                    id: nil,
                    trackId: nil,
                    originalUri: originalUri,
                    copiedUri: nil,
                    importMode: mode,
                    state: .failed,
                    bookmarkData: bookmarkData,
                    errorMessage: message,
                    createdAt: now,
                    updatedAt: now
                )
                try record.insert(db)
            }
        }
    }

    private func fetchFailedImports() async -> [FailedImportEntry] {
        let rows = (try? appDatabase.dbPool.read { db -> [Row] in
            try Row.fetchAll(
                db,
                sql: """
                SELECT id, original_uri, import_mode, bookmark_data
                FROM import_records
                WHERE state = ? AND original_uri IS NOT NULL
                ORDER BY updated_at ASC
                """,
                arguments: [ImportState.failed]
            )
        }) ?? []

        return rows.compactMap { row in
            guard let id: Int64 = row["id"],
                  let originalUri: String = row["original_uri"],
                  let importMode: ImportMode = row["import_mode"] else {
                return nil
            }
            let bookmarkData: Data? = row["bookmark_data"]
            return FailedImportEntry(
                id: id,
                originalUri: originalUri,
                importMode: importMode,
                bookmarkData: bookmarkData
            )
        }
    }

    private func resolveImportURL(originalUri: String, bookmarkData: Data?) -> URL? {
        if let bookmarkData {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), url.isFileURL {
                return url
            }
        }

        if let url = URL(string: originalUri), url.isFileURL {
            return url
        }
        return nil
    }

    private func updateFailedImport(id: Int64, message: String) async {
        let now = Int64(Date().timeIntervalSince1970)
        try? await appDatabase.dbPool.write { db in
            try db.execute(
                sql: """
                UPDATE import_records
                SET error_message = ?, updated_at = ?
                WHERE id = ?
                """,
                arguments: [message, now, id]
            )
        }
    }

    private func deleteFailedImport(id: Int64) async {
        try? await appDatabase.dbPool.write { db in
            try db.execute(
                sql: "DELETE FROM import_records WHERE id = ?",
                arguments: [id]
            )
        }
    }

    func repairMissingArtwork(force: Bool = false) async {
        let rows = (try? appDatabase.dbPool.read { db -> [Row] in
            try Row.fetchAll(
                db,
                sql: """
                SELECT t.*,
                       ta.file_uri AS track_artwork_uri,
                       aa.file_uri AS album_artwork_uri
                FROM tracks t
                LEFT JOIN artworks ta ON ta.id = t.artwork_id
                LEFT JOIN artworks aa ON aa.id = t.album_artwork_id
                WHERE t.source = ? AND t.file_uri IS NOT NULL
                """,
                arguments: [TrackSource.local]
            )
        }) ?? []

        for row in rows {
            await repairArtwork(from: row, force: force)
        }
    }

    struct MissingArtworkScanResult {
        let totalMissing: Int
        let trackIds: [Int64]
    }

    func missingArtworkScan(limit: Int) async -> MissingArtworkScanResult {
        let rows = (try? appDatabase.dbPool.read { db -> [Row] in
            try Row.fetchAll(
                db,
                sql: """
                SELECT t.id AS id,
                       ta.file_uri AS track_artwork_uri,
                       aa.file_uri AS album_artwork_uri
                FROM tracks t
                LEFT JOIN artworks ta ON ta.id = t.artwork_id
                LEFT JOIN artworks aa ON aa.id = t.album_artwork_id
                WHERE t.source = ? AND t.file_uri IS NOT NULL
                ORDER BY t.updated_at DESC
                """,
                arguments: [TrackSource.local]
            )
        }) ?? []

        var results: [Int64] = []
        results.reserveCapacity(min(rows.count, limit))
        var totalMissing = 0
        for row in rows {
            guard let id = row["id"] as Int64? else { continue }
            let trackArtworkUri: String? = row["track_artwork_uri"]
            let albumArtworkUri: String? = row["album_artwork_uri"]
            let hasTrackArtwork = artworkFileExists(trackArtworkUri, fileManager: fileManager)
            let hasAlbumArtwork = artworkFileExists(albumArtworkUri, fileManager: fileManager)
            if !hasTrackArtwork && !hasAlbumArtwork {
                totalMissing += 1
                if results.count < limit {
                    results.append(id)
                }
            }
        }
        return MissingArtworkScanResult(totalMissing: totalMissing, trackIds: results)
    }

    func repairArtwork(forTrackId trackId: Int64, force: Bool = false) async {
        let row = try? appDatabase.dbPool.read { db -> Row? in
            try Row.fetchOne(
                db,
                sql: """
                SELECT t.*,
                       ta.file_uri AS track_artwork_uri,
                       aa.file_uri AS album_artwork_uri
                FROM tracks t
                LEFT JOIN artworks ta ON ta.id = t.artwork_id
                LEFT JOIN artworks aa ON aa.id = t.album_artwork_id
                WHERE t.id = ?
                """,
                arguments: [trackId]
            )
        }
        guard let row else { return }
        await repairArtwork(from: row, force: force)
    }

    func importFiles(
        from urls: [URL],
        mode: ImportMode,
        allowDeleteOriginal: Bool = false,
        operation: OperationKind = .importFiles,
        progress: ((OperationProgress) -> Void)? = nil,
        progressId: UUID? = nil,
        startedAt: Date? = nil
    ) async -> ImportBatchResult {
        let total = urls.count
        let operationId = progressId ?? UUID()
        let operationStart = startedAt ?? Date()
        let operationLabel: String
        switch operation {
        case .importFolder:
            operationLabel = "Importing folder"
        case .importFiles:
            operationLabel = "Importing files"
        case .rescan:
            operationLabel = "Importing files"
        }

        func emit(processed: Int, phase: OperationPhase, message: String? = nil) {
            let text = message ?? "\(operationLabel) \(processed)/\(total)"
            let snapshot = OperationProgress(
                id: operationId,
                operation: operation,
                phase: phase,
                processed: processed,
                total: total,
                message: text,
                startedAt: operationStart,
                updatedAt: Date()
            )
            progress?(snapshot)
        }

        var importedCount = 0
        var relinkedCount = 0
        var skippedCount = 0
        var failures: [String] = []
        emit(processed: 0, phase: .importing)
        var processedCount = 0
        for url in urls {
            do {
                let result = try await importFile(from: url, mode: mode, allowDeleteOriginal: allowDeleteOriginal)
                switch result.outcome {
                case .imported:
                    importedCount += 1
                case .relinkedExisting:
                    relinkedCount += 1
                case .skippedDuplicate:
                    skippedCount += 1
                }
            } catch {
                let name = url.lastPathComponent
                failures.append("\(name): \(errorMessage(from: error))")
                await recordFailedImport(url: url, mode: mode, error: error)
            }
            processedCount += 1
            emit(processed: processedCount, phase: .importing)
        }
        emit(processed: total, phase: .finishing, message: "Finishing...")
        return ImportBatchResult(
            importedCount: importedCount,
            relinkedCount: relinkedCount,
            skippedCount: skippedCount,
            failures: failures
        )
    }

    func retryFailedImports(allowDeleteOriginal: Bool = false) async -> ImportBatchResult {
        let failedEntries = await fetchFailedImports()
        var importedCount = 0
        var relinkedCount = 0
        var skippedCount = 0
        var failures: [String] = []

        for entry in failedEntries {
            guard let url = resolveImportURL(originalUri: entry.originalUri, bookmarkData: entry.bookmarkData) else {
                let message = "Unable to resolve file URL"
                failures.append("\(URL(string: entry.originalUri)?.lastPathComponent ?? entry.originalUri): \(message)")
                await updateFailedImport(id: entry.id, message: message)
                continue
            }

            do {
                let deleteOriginal = allowDeleteOriginal && entry.importMode == .copyThenDelete
                let result = try await importFile(from: url, mode: entry.importMode, allowDeleteOriginal: deleteOriginal)
                switch result.outcome {
                case .imported:
                    importedCount += 1
                case .relinkedExisting:
                    relinkedCount += 1
                case .skippedDuplicate:
                    skippedCount += 1
                }
                await deleteFailedImport(id: entry.id)
            } catch {
                let name = url.lastPathComponent
                let message = errorMessage(from: error)
                failures.append("\(name): \(message)")
                await updateFailedImport(id: entry.id, message: message)
            }
        }

        return ImportBatchResult(
            importedCount: importedCount,
            relinkedCount: relinkedCount,
            skippedCount: skippedCount,
            failures: failures
        )
    }

    private func resolveTrackURL(for track: TrackRecord, trackId: Int64) -> URL? {
        if let bookmarkData = fetchBookmarkData(for: trackId) {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), url.isFileURL {
                return url
            }
        }

        if let fileUri = track.fileUri,
           let url = URL(string: fileUri),
           url.isFileURL {
            return url
        }
        return nil
    }

    private func fetchBookmarkData(for trackId: Int64) -> Data? {
        (try? appDatabase.dbPool.read { db -> Data? in
            try Data.fetchOne(
                db,
                sql: """
                SELECT bookmark_data
                FROM import_records
                WHERE track_id = ?
                ORDER BY updated_at DESC
                LIMIT 1
                """,
                arguments: [trackId]
            )
        }) ?? nil
    }

    private func repairArtwork(from row: Row, force: Bool) async {
        guard let track = try? TrackRecord(row: row) else { return }
        guard let trackId = track.id else { return }

        let trackArtworkUri: String? = row["track_artwork_uri"]
        let albumArtworkUri: String? = row["album_artwork_uri"]
        let hasTrackArtwork = artworkFileExists(trackArtworkUri, fileManager: fileManager)
        let hasAlbumArtwork = artworkFileExists(albumArtworkUri, fileManager: fileManager)
        if !force {
            guard !hasTrackArtwork && !hasAlbumArtwork else { return }
        }

        guard let url = resolveTrackURL(for: track, trackId: trackId) else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard fileManager.fileExists(atPath: url.path) else { return }
        guard let metadata = try? await metadataReader.read(from: url),
              let artworkData = metadata.artworkData else {
            return
        }

        let baseDirectory = AppDatabase.defaultDirectory
        let now = Int64(Date().timeIntervalSince1970)
        try? await backfillArtwork(
            track: track,
            artworkData: artworkData,
            now: now,
            baseDirectory: baseDirectory
        )
    }

    func importFolder(
        from url: URL,
        mode: ImportMode,
        allowDeleteOriginal: Bool = false,
        progress: ((OperationProgress) -> Void)? = nil
    ) async -> ImportBatchResult {
        guard url.isFileURL else {
            return ImportBatchResult(importedCount: 0, relinkedCount: 0, skippedCount: 0, failures: [
                "\(url.lastPathComponent): unsupported URL"
            ])
        }

        let operationId = UUID()
        let operationStart = Date()
        progress?(OperationProgress(
            id: operationId,
            operation: .importFolder,
            phase: .scanning,
            processed: 0,
            total: nil,
            message: "Scanning folder...",
            startedAt: operationStart,
            updatedAt: Date()
        ))

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let files = collectAudioFiles(in: url)
        return await importFiles(
            from: files,
            mode: mode,
            allowDeleteOriginal: allowDeleteOriginal,
            operation: .importFolder,
            progress: progress,
            progressId: operationId,
            startedAt: operationStart
        )
    }

    private func copyToLibrary(from url: URL, expectedSize: Int64?) throws -> URL {
        let directory = try ensureLibraryDirectory()
        let ext = url.pathExtension
        let fileName = ext.isEmpty ? UUID().uuidString : "\(UUID().uuidString).\(ext)"
        let destination = directory.appendingPathComponent(fileName)
        try fileManager.copyItem(at: url, to: destination)
        if let expectedSize, expectedSize > 0 {
            let actualSize = fileSize(for: destination)
            if actualSize != expectedSize {
                try? fileManager.removeItem(at: destination)
                throw LocalImportError.copyVerificationFailed(expected: expectedSize, actual: actualSize)
            }
        }
        return destination
    }

    private func ensureLibraryDirectory() throws -> URL {
        try LocalImportPaths.libraryFilesDirectory(fileManager: fileManager)
    }

    private func fileSize(for url: URL) -> Int64 {
        let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?
            .int64Value ?? 0
        return size
    }

    private func collectAudioFiles(in directory: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentTypeKey, .isHiddenKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isHidden != true,
                  values.isRegularFile == true else {
                continue
            }

            let type = values.contentType ?? UTType(filenameExtension: fileURL.pathExtension)
            guard let type, type.conforms(to: .audio) else { continue }
            results.append(fileURL)
        }
        return results
    }
    
    /// Helper: Upsert an artist by name, returning its ID
    private func upsertArtistId(name: String?, now: Int64, db: Database) throws -> Int64? {
        guard let name else { return nil }

        if let existing = try ArtistRecord
            .filter(Column("name") == name)
            .fetchOne(db) {
            return existing.id
        }

        let record = ArtistRecord(
            id: nil,
            name: name,
            sortName: nil,
            isFavorite: false,
            createdAt: now,
            updatedAt: now
        )
        try record.insert(db)
        return record.id ?? db.lastInsertedRowID
    }
    
    /// Helper: Upsert an album by name and album artist, returning its ID
    private func upsertAlbumId(
        name: String?,
        albumArtistId: Int64?,
        releaseYear: Int?,
        artworkId: Int64?,
        now: Int64,
        db: Database
    ) throws -> Int64? {
        guard let name else { return nil }

        let query = AlbumRecord.filter(Column("name") == name)
        let filtered: QueryInterfaceRequest<AlbumRecord>
        if let albumArtistId {
            filtered = query.filter(Column("album_artist_id") == albumArtistId)
        } else {
            filtered = query.filter(Column("album_artist_id") == nil)
        }

        if var existing = try filtered.fetchOne(db) {
            var didUpdate = false
            if existing.releaseYear == nil, let releaseYear {
                existing.releaseYear = releaseYear
                didUpdate = true
            }
            if existing.artworkId == nil, let artworkId {
                existing.artworkId = artworkId
                didUpdate = true
            }
            if didUpdate {
                existing.updatedAt = now
                try existing.update(db)
            }
            return existing.id
        }

        let record = AlbumRecord(
            id: nil,
            name: name,
            albumArtistId: albumArtistId,
            releaseYear: releaseYear,
            artworkId: artworkId,
            isFavorite: false,
            createdAt: now,
            updatedAt: now
        )
        try record.insert(db)
        return record.id ?? db.lastInsertedRowID
    }

    private func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func cleanedLyrics(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
