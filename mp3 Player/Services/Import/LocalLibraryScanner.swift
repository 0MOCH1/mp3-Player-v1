import Foundation
import GRDB
import UniformTypeIdentifiers

@MainActor
final class StartupScanCoordinator {
    static let shared = StartupScanCoordinator()
    private var didScan = false

    func scanIfNeeded(appDatabase: AppDatabase) async {
        guard !didScan else { return }
        didScan = true

        let scanner = LocalLibraryScanner(appDatabase: appDatabase)
        await scanner.scanAppFolders()

        await autoRepairMissingArtworkIfNeeded(appDatabase: appDatabase)
    }

    private func autoRepairMissingArtworkIfNeeded(appDatabase: AppDatabase) async {
        let importer = LocalImportService(appDatabase: appDatabase)
        let scanLimit = 200
        let cooldownSeconds: TimeInterval = 6 * 60 * 60
        let lastRun = ArtworkRepairStatus.lastRunAt()
        let shouldSkip = lastRun.map { Date().timeIntervalSince($0) < cooldownSeconds } ?? false

        Task.detached(priority: .utility) { [importer, scanLimit, cooldownSeconds, shouldSkip] in
            if shouldSkip {
                await MainActor.run {
                    let hours = Int(cooldownSeconds / 3600)
                    ArtworkRepairStatus.set("Auto repair: skipped (\(hours)h cooldown)")
                }
                return
            }

            let scan = await importer.missingArtworkScan(limit: scanLimit)
            guard scan.totalMissing > 0 else {
                await MainActor.run {
                    ArtworkRepairStatus.set(nil)
                }
                return
            }

            let total = scan.totalMissing
            let targetCount = scan.trackIds.count
            await MainActor.run {
                if total > targetCount {
                    ArtworkRepairStatus.set("Auto repair: running (\(targetCount)/\(total))")
                } else {
                    ArtworkRepairStatus.set("Auto repair: running (\(total))")
                }
            }

            for trackId in scan.trackIds {
                await importer.repairArtwork(forTrackId: trackId)
            }

            await MainActor.run {
                if total > targetCount {
                    ArtworkRepairStatus.set("Auto repair: complete (\(targetCount)/\(total))")
                } else {
                    ArtworkRepairStatus.set("Auto repair: complete (\(total))")
                }
                ArtworkRepairStatus.markRunCompleted(count: targetCount)
                NotificationCenter.default.post(name: .artworkRepairDidComplete, object: nil)
            }
        }
    }
}

final class LocalLibraryScanner {
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

    func scanAppFolders(
        repairMissingArtwork: Bool = false,
        forceArtworkRebuild: Bool = false,
        progress: ((OperationProgress) -> Void)? = nil
    ) async {
        let directories: [URL]
        do {
            directories = try LocalImportPaths.scanDirectories(fileManager: fileManager)
        } catch {
            return
        }

        let operationId = UUID()
        let operationStart = Date()
        let operation = OperationKind.rescan
        func emit(
            phase: OperationPhase,
            processed: Int,
            total: Int?,
            message: String
        ) {
            let snapshot = OperationProgress(
                id: operationId,
                operation: operation,
                phase: phase,
                processed: processed,
                total: total,
                message: message,
                startedAt: operationStart,
                updatedAt: Date()
            )
            progress?(snapshot)
        }

        emit(phase: .preparing, processed: 0, total: nil, message: "Rescan: preparing...")

        let existingRows = (try? appDatabase.dbPool.read { db -> [Row] in
            try Row.fetchAll(
                db,
                sql: """
                SELECT t.file_uri,
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
        var knownFiles = Set<String>()
        var needsArtwork = Set<String>()
        for row in existingRows {
            let uri: String = row["file_uri"]
            knownFiles.insert(uri)
            let trackArtworkUri: String? = row["track_artwork_uri"]
            let albumArtworkUri: String? = row["album_artwork_uri"]
            let hasTrackArtwork = artworkFileExists(trackArtworkUri)
            let hasAlbumArtwork = artworkFileExists(albumArtworkUri)
            if !hasTrackArtwork && !hasAlbumArtwork {
                needsArtwork.insert(uri)
            }
        }

        let importer = LocalImportService(
            appDatabase: appDatabase,
            metadataReader: metadataReader,
            fileManager: fileManager
        )

        var allFiles: [URL] = []
        for directory in directories {
            allFiles.append(contentsOf: collectAudioFiles(in: directory))
        }
        let total = allFiles.count
        emit(phase: .scanning, processed: 0, total: total, message: "Rescan 0/\(total)")

        var processed = 0
        for fileURL in allFiles {
            let uri = fileURL.absoluteString
            if knownFiles.contains(uri) {
                guard needsArtwork.contains(uri) else {
                    processed += 1
                    emit(phase: .scanning, processed: processed, total: total, message: "Rescan \(processed)/\(total)")
                    continue
                }
            }
            if let _ = try? await importer.importFile(from: fileURL, mode: .reference) {
                knownFiles.insert(uri)
                needsArtwork.remove(uri)
            }
            processed += 1
            emit(phase: .scanning, processed: processed, total: total, message: "Rescan \(processed)/\(total)")
        }

        if repairMissingArtwork {
            emit(phase: .repairing, processed: processed, total: nil, message: "Repairing artwork...")
            await importer.repairMissingArtwork(force: forceArtworkRebuild)
        }
        emit(phase: .finishing, processed: total, total: total, message: "Rescan complete.")
    }

    private func collectAudioFiles(in directory: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentTypeKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else {
                continue
            }

            let type = values.contentType ?? UTType(filenameExtension: fileURL.pathExtension)
            guard let type, type.conforms(to: .audio) else { continue }
            results.append(fileURL)
        }
        return results
    }

    private func artworkFileExists(_ uri: String?) -> Bool {
        guard let uri,
              let url = URL(string: uri),
              url.isFileURL else {
            return false
        }
        return fileManager.fileExists(atPath: url.path)
    }
}
