import Combine
import GRDB
import SwiftUI

struct SettingsView: View {
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.playbackController) private var playbackController
    @EnvironmentObject private var progressCenter: ProgressCenter
    @AppStorage("import_mode") private var importModeRaw = ImportMode.copy.rawValue
    @AppStorage("import_allow_delete_original") private var allowDeleteOriginal = false
    @AppStorage(ArtworkRepairStatus.statusKey) private var autoRepairStatus = ""
    @StateObject private var viewModel = SettingsViewModel()
    @State private var rescanStatus: String?
    @State private var cleanupStatus: String?
    @State private var retryStatus: String?
    @State private var repairStatus: String?
    @State private var showsCleanupConfirm = false
    @State private var showsClearFailedConfirm = false
    @State private var showsRepairConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Import") {
                    Picker("Import Mode", selection: $importModeRaw) {
                        ForEach(ImportMode.allCases, id: \.rawValue) { mode in
                            Text(importModeLabel(mode)).tag(mode.rawValue)
                        }
                    }

                    if selectedImportMode == .copyThenDelete {
                        Toggle("Delete original after copy", isOn: $allowDeleteOriginal)
                    }

                    Button("Rescan Library") {
                        rescanLibrary()
                    }

                    if let rescanStatus {
                        Text(rescanStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Retry Failed Imports") {
                        retryFailedImports()
                    }

                    if let retryStatus {
                        Text(retryStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !autoRepairStatus.isEmpty {
                        Text(autoRepairStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Storage") {
                    Text("Database: \(viewModel.databaseSizeLabel)")
                    Text("Library Files: \(viewModel.libraryFilesSizeLabel)")
                    Text("Import Folder: \(viewModel.importFolderSizeLabel)")

                    Button("Remove Orphaned Library Files") {
                        showsCleanupConfirm = true
                    }

                    if let cleanupStatus {
                        Text(cleanupStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Repair Database") {
                        showsRepairConfirm = true
                    }

                    if let repairStatus {
                        Text(repairStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Diagnostics") {
                    Text("Tracks: \(viewModel.counts.tracks)")
                    Text("Albums: \(viewModel.counts.albums)")
                    Text("Artists: \(viewModel.counts.artists)")
                    Text("Playlists: \(viewModel.counts.playlists)")
                    Text("Queue Items: \(viewModel.counts.queueItems)")
                    Text("History Entries: \(viewModel.counts.historyEntries)")
                    Text("Playback Positions: \(viewModel.counts.playbackPositions)")
                    Text("Playback State: \(viewModel.counts.playbackState)")
                    Text("Missing: \(viewModel.counts.missing)")
                    Text("Import Records: \(viewModel.counts.importRecords)")
                    Text("Import Failures: \(viewModel.counts.failedImports)")
                    Text("Missing (Not Found): \(viewModel.counts.missingNotFound)")
                    Text("Missing (Permission): \(viewModel.counts.missingPermission)")
                    Text("Missing (Invalid URI): \(viewModel.counts.missingInvalidUri)")
                }

                Section("Failed Imports") {
                    if viewModel.failedImports.isEmpty {
                        Text("None")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.failedImports) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.fileName)
                                Text(item.message)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button("Clear Failed Imports") {
                            showsClearFailedConfirm = true
                        }
                    }
                }

                Section("Permissions") {
                    Text("Music library access")
                    Text("Files access")
                }
            }
            .appList()
            .navigationTitle("Settings")
            .confirmationDialog(
                "Remove Orphaned Files?",
                isPresented: $showsCleanupConfirm,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    removeOrphanedFiles()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes files in the app library folder that are no longer referenced.")
            }
            .confirmationDialog(
                "Clear Failed Imports?",
                isPresented: $showsClearFailedConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear", role: .destructive) {
                    clearFailedImports()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes failed import records from the database.")
            }
            .confirmationDialog(
                "Repair Database?",
                isPresented: $showsRepairConfirm,
                titleVisibility: .visible
            ) {
                Button("Repair", role: .destructive) {
                    repairDatabase()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cleans orphaned records (queue/history/recents/etc).")
            }
        }
        .onAppear {
            viewModel.refresh(appDatabase: appDatabase)
        }
        .appScreen()
    }

    private var selectedImportMode: ImportMode {
        ImportMode(rawValue: importModeRaw) ?? .reference
    }

    private func importModeLabel(_ mode: ImportMode) -> String {
        switch mode {
        case .reference:
            return "Reference"
        case .copy:
            return "Copy"
        case .copyThenDelete:
            return "Copy then delete"
        }
    }

    private func rescanLibrary() {
        guard let appDatabase else {
            rescanStatus = "Database unavailable."
            return
        }
        rescanStatus = "Scanning..."
        Task {
            let scanner = LocalLibraryScanner(appDatabase: appDatabase)
            await scanner.scanAppFolders(
                repairMissingArtwork: true,
                forceArtworkRebuild: true,
                progress: { progress in
                    Task { @MainActor in
                        progressCenter.update(progress)
                    }
                }
            )
            await MainActor.run {
                rescanStatus = "Scan complete."
                viewModel.refresh(appDatabase: appDatabase)
                playbackController?.refreshQueueArtwork()
                progressCenter.clear()
            }
        }
    }

    private func removeOrphanedFiles() {
        guard let appDatabase else {
            cleanupStatus = "Database unavailable."
            return
        }
        cleanupStatus = "Removing..."
        Task {
            let libraryDirectory = (try? LocalImportPaths.libraryFilesDirectory()) ?? AppDatabase.defaultDirectory
            let result = await SettingsCleanup.removeOrphanedLibraryFiles(
                appDatabase: appDatabase,
                libraryDirectory: libraryDirectory
            )
            await MainActor.run {
                cleanupStatus = "Removed \(result.removedCount) files (\(result.removedSizeLabel))."
                viewModel.refresh(appDatabase: appDatabase)
            }
        }
    }

    private func retryFailedImports() {
        guard let appDatabase else {
            retryStatus = "Database unavailable."
            return
        }
        retryStatus = "Retrying..."
        Task {
            let importer = LocalImportService(appDatabase: appDatabase)
            let result = await importer.retryFailedImports(allowDeleteOriginal: allowDeleteOriginal)
            await MainActor.run {
                let summary = [
                    "Imported \(result.importedCount)",
                    "Relinked \(result.relinkedCount)",
                    "Skipped \(result.skippedCount)",
                    "Failed \(result.failures.count)",
                ].joined(separator: ", ")
                if result.failures.isEmpty {
                    retryStatus = summary
                } else {
                    let detail = result.failures.first ?? "Unknown error."
                    retryStatus = "\(summary). \(detail)"
                }
                viewModel.refresh(appDatabase: appDatabase)
            }
        }
    }

    private func clearFailedImports() {
        guard let appDatabase else { return }
        Task {
            try? await appDatabase.dbPool.write { db in
                try db.execute(
                    sql: "DELETE FROM import_records WHERE state = ?",
                    arguments: [ImportState.failed]
                )
            }
            await MainActor.run {
                viewModel.refresh(appDatabase: appDatabase)
            }
        }
    }

    private func repairDatabase() {
        guard let appDatabase else {
            repairStatus = "Database unavailable."
            return
        }
        repairStatus = "Repairing..."
        Task {
            let result = await SettingsCleanup.repairDatabase(appDatabase: appDatabase)
            await MainActor.run {
                repairStatus = result.summary
                viewModel.refresh(appDatabase: appDatabase)
            }
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    struct Counts {
        let tracks: Int
        let albums: Int
        let artists: Int
        let playlists: Int
        let queueItems: Int
        let historyEntries: Int
        let playbackPositions: Int
        let playbackState: Int
        let missing: Int
        let importRecords: Int
        let failedImports: Int
        let missingNotFound: Int
        let missingPermission: Int
        let missingInvalidUri: Int
    }

    @Published var counts = Counts(
        tracks: 0,
        albums: 0,
        artists: 0,
        playlists: 0,
        queueItems: 0,
        historyEntries: 0,
        playbackPositions: 0,
        playbackState: 0,
        missing: 0,
        importRecords: 0,
        failedImports: 0,
        missingNotFound: 0,
        missingPermission: 0,
        missingInvalidUri: 0
    )
    @Published var databaseSizeLabel = "—"
    @Published var libraryFilesSizeLabel = "—"
    @Published var importFolderSizeLabel = "—"
    @Published var failedImports: [FailedImportItem] = []

    func refresh(appDatabase: AppDatabase?) {
        guard let appDatabase else { return }
        Task {
            await loadData(appDatabase: appDatabase)
        }
    }

    private func loadData(appDatabase: AppDatabase) async {
        let dbCounts = (try? await appDatabase.dbPool.read { db -> Counts in
            let tracks = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM tracks") ?? 0
            let albums = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM albums") ?? 0
            let artists = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM artists") ?? 0
            let playlists = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM playlists") ?? 0
            let queueItems = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM queue_items") ?? 0
            let historyEntries = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM history_entries") ?? 0
            let playbackPositions = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM playback_positions") ?? 0
            let playbackState = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM playback_state") ?? 0
            let missing = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM tracks WHERE is_missing = 1") ?? 0
            let importRecords = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM import_records") ?? 0
            let failedImports = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM import_records WHERE state = ?",
                arguments: [ImportState.failed]
            ) ?? 0
            let missingNotFound = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM tracks WHERE is_missing = 1 AND missing_reason = ?",
                arguments: [MissingReason.notFound.rawValue]
            ) ?? 0
            let missingPermission = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM tracks WHERE is_missing = 1 AND missing_reason = ?",
                arguments: [MissingReason.permission.rawValue]
            ) ?? 0
            let missingInvalidUri = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM tracks WHERE is_missing = 1 AND missing_reason = ?",
                arguments: [MissingReason.invalidUri.rawValue]
            ) ?? 0
            return Counts(
                tracks: tracks,
                albums: albums,
                artists: artists,
                playlists: playlists,
                queueItems: queueItems,
                historyEntries: historyEntries,
                playbackPositions: playbackPositions,
                playbackState: playbackState,
                missing: missing,
                importRecords: importRecords,
                failedImports: failedImports,
                missingNotFound: missingNotFound,
                missingPermission: missingPermission,
                missingInvalidUri: missingInvalidUri
            )
        }) ?? Counts(
            tracks: 0,
            albums: 0,
            artists: 0,
            playlists: 0,
            queueItems: 0,
            historyEntries: 0,
            playbackPositions: 0,
            playbackState: 0,
            missing: 0,
            importRecords: 0,
            failedImports: 0,
            missingNotFound: 0,
            missingPermission: 0,
            missingInvalidUri: 0
        )

        let failedImportItems = (try? await appDatabase.dbPool.read { db -> [FailedImportItem] in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, original_uri, error_message
                FROM import_records
                WHERE state = ?
                ORDER BY updated_at DESC
                LIMIT 20
                """,
                arguments: [ImportState.failed]
            )
            return rows.compactMap { row in
                guard let id: Int64 = row["id"] else { return nil }
                let originalUri: String? = row["original_uri"]
                let message = row["error_message"] as String? ?? "Unknown error"
                let fileName = originalUri.flatMap { URL(string: $0)?.lastPathComponent } ?? "Unknown file"
                return FailedImportItem(id: id, fileName: fileName, message: message)
            }
        }) ?? []

        let databaseDirectory = AppDatabase.defaultDirectory
        let libraryDirectory = (try? LocalImportPaths.libraryFilesDirectory()) ?? databaseDirectory
        let importDirectory = (try? LocalImportPaths.appImportDirectory()) ?? databaseDirectory
        let sizes = await Task.detached(priority: .utility) {
            SettingsStorage.computeSizes(
                databaseDirectory: databaseDirectory,
                libraryDirectory: libraryDirectory,
                importDirectory: importDirectory
            )
        }.value

        counts = dbCounts
        databaseSizeLabel = SettingsStorage.bytesString(sizes.databaseBytes)
        libraryFilesSizeLabel = SettingsStorage.bytesString(sizes.libraryFilesBytes)
        importFolderSizeLabel = SettingsStorage.bytesString(sizes.importFolderBytes)
        failedImports = failedImportItems
    }
}

struct FailedImportItem: Identifiable {
    let id: Int64
    let fileName: String
    let message: String
}

private enum SettingsStorage {
    struct SizeSnapshot {
        let databaseBytes: Int64
        let libraryFilesBytes: Int64
        let importFolderBytes: Int64
    }

    nonisolated static func computeSizes(
        databaseDirectory: URL,
        libraryDirectory: URL,
        importDirectory: URL
    ) -> SizeSnapshot {
        let databaseBytes = databaseFileSize(databaseDirectory: databaseDirectory)
        let libraryFilesBytes = directorySize(libraryDirectory)
        let importFolderBytes = directorySize(importDirectory)
        return SizeSnapshot(
            databaseBytes: databaseBytes,
            libraryFilesBytes: libraryFilesBytes,
            importFolderBytes: importFolderBytes
        )
    }

    nonisolated static func bytesString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    nonisolated private static func databaseFileSize(databaseDirectory: URL) -> Int64 {
        let base = databaseDirectory.appendingPathComponent("app.sqlite")
        let wal = databaseDirectory.appendingPathComponent("app.sqlite-wal")
        let shm = databaseDirectory.appendingPathComponent("app.sqlite-shm")
        return fileSize(base) + fileSize(wal) + fileSize(shm)
    }

    nonisolated private static func fileSize(_ url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?
            .int64Value ?? 0
    }

    nonisolated private static func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}

private enum SettingsCleanup {
    struct CleanupResult {
        let removedCount: Int
        let removedBytes: Int64

        var removedSizeLabel: String {
            SettingsStorage.bytesString(removedBytes)
        }
    }

    static func removeOrphanedLibraryFiles(
        appDatabase: AppDatabase,
        libraryDirectory: URL
    ) async -> CleanupResult {
        let referenced = (try? await appDatabase.dbPool.read { db -> Set<String> in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT file_uri FROM tracks WHERE source = ? AND file_uri IS NOT NULL",
                arguments: [TrackSource.local]
            )
            let paths = rows.compactMap { row -> String? in
                guard let uri = row["file_uri"] as String? else { return nil }
                guard let url = URL(string: uri), url.isFileURL else { return nil }
                guard url.path.hasPrefix(libraryDirectory.path) else { return nil }
                return url.path
            }
            return Set(paths)
        }) ?? []

        return await Task.detached(priority: .utility) {
            removeOrphanedLibraryFilesSync(
                libraryDirectory: libraryDirectory,
                referenced: referenced
            )
        }.value
    }

    struct DatabaseCleanupResult {
        let queueItems: Int
        let historyEntries: Int
        let playbackState: Int
        let playbackPositions: Int
        let lyrics: Int
        let metadataOverrides: Int
        let playlistTracks: Int
        let importRecords: Int
        let recentItems: Int
        let listeningStats: Int
        let tracksFts: Int

        var total: Int {
            queueItems
                + historyEntries
                + playbackState
                + playbackPositions
                + lyrics
                + metadataOverrides
                + playlistTracks
                + importRecords
                + recentItems
                + listeningStats
                + tracksFts
        }

        var summary: String {
            guard total > 0 else { return "No database issues found." }
            let details = [
                ("Queue", queueItems),
                ("History", historyEntries),
                ("State", playbackState),
                ("Positions", playbackPositions),
                ("Lyrics", lyrics),
                ("Metadata", metadataOverrides),
                ("Playlists", playlistTracks),
                ("Imports", importRecords),
                ("Recents", recentItems),
                ("Stats", listeningStats),
                ("FTS", tracksFts),
            ].filter { $0.1 > 0 }

            let detailText = details.prefix(4)
                .map { "\($0.0) \($0.1)" }
                .joined(separator: ", ")
            let suffix = details.count > 4 ? ", ..." : ""
            return "Removed \(total) records (\(detailText)\(suffix))."
        }
    }

    static func repairDatabase(appDatabase: AppDatabase) async -> DatabaseCleanupResult {
        let empty = DatabaseCleanupResult(
            queueItems: 0,
            historyEntries: 0,
            playbackState: 0,
            playbackPositions: 0,
            lyrics: 0,
            metadataOverrides: 0,
            playlistTracks: 0,
            importRecords: 0,
            recentItems: 0,
            listeningStats: 0,
            tracksFts: 0
        )

        return (try? await appDatabase.dbPool.write { db -> DatabaseCleanupResult in
            try db.execute(
                sql: """
                DELETE FROM queue_items
                WHERE source = ?
                  AND NOT EXISTS (
                      SELECT 1 FROM tracks t
                      WHERE t.source = queue_items.source
                        AND t.source_track_id = queue_items.source_track_id
                  )
                """,
                arguments: [TrackSource.local]
            )
            let queueItems = db.changesCount

            try db.execute(
                sql: """
                DELETE FROM history_entries
                WHERE source = ?
                  AND NOT EXISTS (
                      SELECT 1 FROM tracks t
                      WHERE t.source = history_entries.source
                        AND t.source_track_id = history_entries.source_track_id
                  )
                """,
                arguments: [TrackSource.local]
            )
            let historyEntries = db.changesCount

            try db.execute(
                sql: """
                DELETE FROM playback_state
                WHERE source = ?
                  AND NOT EXISTS (
                      SELECT 1 FROM tracks t
                      WHERE t.source = playback_state.source
                        AND t.source_track_id = playback_state.source_track_id
                  )
                """,
                arguments: [TrackSource.local]
            )
            let playbackState = db.changesCount

            try db.execute(
                sql: """
                DELETE FROM playback_positions
                WHERE source = ?
                  AND NOT EXISTS (
                      SELECT 1 FROM tracks t
                      WHERE t.source = playback_positions.source
                        AND t.source_track_id = playback_positions.source_track_id
                  )
                """,
                arguments: [TrackSource.local]
            )
            let playbackPositions = db.changesCount

            try db.execute(
                sql: """
                DELETE FROM lyrics
                WHERE source = ?
                  AND NOT EXISTS (
                      SELECT 1 FROM tracks t
                      WHERE t.source = lyrics.source
                        AND t.source_track_id = lyrics.source_track_id
                  )
                """,
                arguments: [TrackSource.local]
            )
            let lyrics = db.changesCount

            try db.execute(
                sql: """
                DELETE FROM metadata_overrides
                WHERE NOT EXISTS (
                    SELECT 1 FROM tracks t
                    WHERE t.id = metadata_overrides.track_id
                )
                """
            )
            let metadataOverrides = db.changesCount

            try db.execute(
                sql: """
                DELETE FROM playlist_tracks
                WHERE NOT EXISTS (
                    SELECT 1 FROM playlists p
                    WHERE p.id = playlist_tracks.playlist_id
                )
                   OR NOT EXISTS (
                    SELECT 1 FROM tracks t
                    WHERE t.id = playlist_tracks.track_id
                )
                """
            )
            let playlistTracks = db.changesCount

            try db.execute(
                sql: """
                DELETE FROM import_records
                WHERE track_id IS NOT NULL
                  AND NOT EXISTS (
                      SELECT 1 FROM tracks t
                      WHERE t.id = import_records.track_id
                  )
                """
            )
            let importRecords = db.changesCount

            let recentAlbumType = RecentItemType.album.rawValue
            try db.execute(
                sql: """
                DELETE FROM recent_items
                WHERE entity_type = ?
                  AND NOT EXISTS (
                      SELECT 1 FROM albums a
                      WHERE a.id = recent_items.entity_id
                  )
                """,
                arguments: [recentAlbumType]
            )
            let recentAlbums = db.changesCount

            let recentPlaylistType = RecentItemType.playlist.rawValue
            try db.execute(
                sql: """
                DELETE FROM recent_items
                WHERE entity_type = ?
                  AND NOT EXISTS (
                      SELECT 1 FROM playlists p
                      WHERE p.id = recent_items.entity_id
                  )
                """,
                arguments: [recentPlaylistType]
            )
            let recentPlaylists = db.changesCount

            let recentArtistType = RecentItemType.artist.rawValue
            try db.execute(
                sql: """
                DELETE FROM recent_items
                WHERE entity_type = ?
                  AND NOT EXISTS (
                      SELECT 1 FROM artists a
                      WHERE a.id = recent_items.entity_id
                  )
                """,
                arguments: [recentArtistType]
            )
            let recentArtists = db.changesCount
            let recentItems = recentAlbums + recentPlaylists + recentArtists

            try db.execute(
                sql: """
                DELETE FROM listening_stats
                WHERE NOT EXISTS (
                    SELECT 1 FROM artists a
                    WHERE a.id = listening_stats.artist_id
                )
                """
            )
            let listeningStats = db.changesCount

            try db.execute(
                sql: """
                DELETE FROM tracks_fts
                WHERE rowid NOT IN (SELECT id FROM tracks)
                """
            )
            let tracksFts = db.changesCount

            return DatabaseCleanupResult(
                queueItems: queueItems,
                historyEntries: historyEntries,
                playbackState: playbackState,
                playbackPositions: playbackPositions,
                lyrics: lyrics,
                metadataOverrides: metadataOverrides,
                playlistTracks: playlistTracks,
                importRecords: importRecords,
                recentItems: recentItems,
                listeningStats: listeningStats,
                tracksFts: tracksFts
            )
        }) ?? empty
    }

    nonisolated private static func removeOrphanedLibraryFilesSync(
        libraryDirectory: URL,
        referenced: Set<String>
    ) -> CleanupResult {
        guard let enumerator = FileManager.default.enumerator(
            at: libraryDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return CleanupResult(removedCount: 0, removedBytes: 0)
        }

        var removedCount = 0
        var removedBytes: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            let path = fileURL.path
            guard !referenced.contains(path) else { continue }
            let size = Int64(values.fileSize ?? 0)
            if (try? FileManager.default.removeItem(at: fileURL)) != nil {
                removedCount += 1
                removedBytes += size
            }
        }

        return CleanupResult(removedCount: removedCount, removedBytes: removedBytes)
    }
}

#Preview {
    SettingsView()
        .environmentObject(ProgressCenter())
}
