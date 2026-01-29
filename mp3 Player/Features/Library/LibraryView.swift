import GRDB
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Binding var showsSettings: Bool
    @Binding var showsImport: Bool
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.playbackController) private var playbackController
    @EnvironmentObject private var progressCenter: ProgressCenter
    @StateObject private var viewModel = LibraryViewModel()
    @AppStorage("import_mode") private var importModeRaw = ImportMode.copy.rawValue
    @AppStorage("import_allow_delete_original") private var allowDeleteOriginal = false
    @State private var isImporting = false
    @State private var importStatus: String?
    @State private var activeImporter: ActiveImporter?
    @State private var isImporterPresented = false
    @State private var missingStatus: String?
    @State private var showsNowPlaying = false
    private let thresholdScrollOffset: CGFloat = 48

    var body: some View {
        NavigationStack {
            List {
                NavigationLink() {
                    TrackListView()
                } label: { Label("Tracks", systemImage: "music.note") }

                NavigationLink() {
                    AlbumListView()
                } label: { Label("Albums", systemImage: "square.stack") }

                NavigationLink() {
                    ArtistListView()
                } label: { Label("Artists", systemImage: "music.microphone") }

                NavigationLink() {
                    PlaylistListView()
                } label: { Label("Playlists", systemImage: "music.note.list") }

                if !viewModel.missingTracks.isEmpty {
                    Section("Missing Files") {
                        ForEach(viewModel.missingTracks) { track in
                            VStack(alignment: .leading) {
                                Text(track.title)
                                if let artist = track.artist {
                                    Text(artist)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                if let reasonValue = track.missingReason,
                                   let reason = MissingReason(rawValue: reasonValue) {
                                    Text(reason.displayLabel)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button {
                                    activeImporter = .relink(track)
                                    isImporterPresented = true
                                } label: {
                                    Text("Relink")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    deleteMissingTrack(track)
                                } label: {
                                    Text("Delete")
                                }
                            }
                        }

                        if let missingStatus {
                            Text(missingStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .appList()
            .navigationTitle("Library")
            .toolbarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showsImport = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: importerContentTypes,
            allowsMultipleSelection: activeImporter?.allowsMultipleSelection ?? false
        ) { result in
            guard let importer = activeImporter else { return }
            switch importer {
            case .importFiles:
                handleFileImport(result)
            case .importFolder:
                handleFolderImport(result)
            case .relink(let track):
                handleRelink(result, target: track)
            }
            activeImporter = nil
            isImporterPresented = false
        }
        .sheet(isPresented: $showsNowPlaying) {
            NowPlayingView()
        }
        // Header のインポートボタンで開くインポート設定シート
        .sheet(isPresented: $showsImport) {
            NavigationStack {
                List {
                    LibraryImportSection(
                        importModeRaw: $importModeRaw,
                        allowDeleteOriginal: $allowDeleteOriginal,
                        isImporting: $isImporting,
                        importStatus: $importStatus,
                        activeImporter: $activeImporter,
                        isImporterPresented: $isImporterPresented
                    )
                }
                .appList()
                .navigationTitle("Import")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showsImport = false }
                    }
                }
            }
        }
        .appScreen()
        .onAppear {
            viewModel.loadIfNeeded(appDatabase: appDatabase)
        }
    }

    private var selectedImportMode: ImportMode {
        ImportMode(rawValue: importModeRaw) ?? .reference
    }

    private var importerContentTypes: [UTType] {
        activeImporter?.allowedContentTypes ?? [.audio]
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

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard let appDatabase else {
            importStatus = "Database unavailable."
            return
        }

        switch result {
        case .failure(let error):
            importStatus = "Import failed: \(error.localizedDescription)"
        case .success(let urls):
            guard !urls.isEmpty else {
                importStatus = "No files selected."
                return
            }

            isImporting = true
            importStatus = "Importing..."
            let mode = selectedImportMode
            let allowDelete = allowDeleteOriginal && mode == .copyThenDelete
            let importer = LocalImportService(appDatabase: appDatabase)
            let progressHandler: (OperationProgress) -> Void = { progress in
                Task { @MainActor in
                    progressCenter.update(progress)
                }
            }

            Task {
                let result = await importer.importFiles(
                    from: urls,
                    mode: mode,
                    allowDeleteOriginal: allowDelete,
                    progress: progressHandler
                )
                await MainActor.run {
                    isImporting = false
                    let summary = [
                        "Imported \(result.importedCount)",
                        "Relinked \(result.relinkedCount)",
                        "Skipped \(result.skippedCount)",
                        "Failed \(result.failures.count)",
                    ].joined(separator: ", ")
                    if result.failures.isEmpty {
                        importStatus = summary
                    } else {
                        let detail = result.failures.first ?? "Unknown error."
                        importStatus = "\(summary). \(detail)"
                    }
                    progressCenter.clear()
                    viewModel.reload(appDatabase: appDatabase)
                }
            }
        }
    }

    private func handleFolderImport(_ result: Result<[URL], Error>) {
        guard let appDatabase else {
            importStatus = "Database unavailable."
            return
        }

        switch result {
        case .failure(let error):
            importStatus = "Import failed: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else {
                importStatus = "No folder selected."
                return
            }

            isImporting = true
            importStatus = "Importing..."
            let mode = selectedImportMode
            let allowDelete = allowDeleteOriginal && mode == .copyThenDelete
            let importer = LocalImportService(appDatabase: appDatabase)
            let progressHandler: (OperationProgress) -> Void = { progress in
                Task { @MainActor in
                    progressCenter.update(progress)
                }
            }

            Task {
                let result = await importer.importFolder(
                    from: url,
                    mode: mode,
                    allowDeleteOriginal: allowDelete,
                    progress: progressHandler
                )
                await MainActor.run {
                    isImporting = false
                    let summary = [
                        "Imported \(result.importedCount)",
                        "Relinked \(result.relinkedCount)",
                        "Skipped \(result.skippedCount)",
                        "Failed \(result.failures.count)",
                    ].joined(separator: ", ")
                    if result.failures.isEmpty {
                        importStatus = summary
                    } else {
                        let detail = result.failures.first ?? "Unknown error."
                        importStatus = "\(summary). \(detail)"
                    }
                    progressCenter.clear()
                    viewModel.reload(appDatabase: appDatabase)
                }
            }
        }
    }


    private func handleRelink(_ result: Result<[URL], Error>, target: MissingTrackSummary) {
        switch result {
        case .failure(let error):
            missingStatus = "Relink failed: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else {
                missingStatus = "No file selected."
                return
            }
            relinkMissingTrack(target, to: url)
        }
    }

    private func relinkMissingTrack(_ track: MissingTrackSummary, to url: URL) {
        guard let appDatabase else {
            missingStatus = "Database unavailable."
            return
        }
        guard url.isFileURL else {
            missingStatus = "Unsupported file."
            return
        }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let bookmarkData = try? url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let now = Int64(Date().timeIntervalSince1970)
        let fileUri = url.absoluteString

        Task {
            do {
                try await appDatabase.dbPool.write { db in
                    try db.execute(
                        sql: """
                        UPDATE tracks
                        SET file_uri = ?,
                            is_missing = 0,
                            missing_reason = NULL,
                            updated_at = ?
                        WHERE id = ?
                        """,
                        arguments: [fileUri, now, track.id]
                    )

                    let importRecord = ImportRecord(
                        id: nil,
                        trackId: track.id,
                        originalUri: fileUri,
                        copiedUri: nil,
                        importMode: .reference,
                        state: .referenced,
                        bookmarkData: bookmarkData,
                        errorMessage: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                    try importRecord.insert(db)
                }
                let importer = LocalImportService(appDatabase: appDatabase)
                await importer.repairArtwork(forTrackId: track.id)
                await MainActor.run {
                    missingStatus = "Relinked \(track.title)."
                    viewModel.reload(appDatabase: appDatabase)
                }
            } catch {
                await MainActor.run {
                    missingStatus = "Relink failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteMissingTrack(_ track: MissingTrackSummary) {
        guard let appDatabase else {
            missingStatus = "Database unavailable."
            return
        }

        Task {
            do {
                try await appDatabase.dbPool.write { db in
                    try db.execute(
                        sql: "DELETE FROM tracks WHERE id = ?",
                        arguments: [track.id]
                    )
                    try db.execute(
                        sql: "DELETE FROM import_records WHERE track_id = ?",
                        arguments: [track.id]
                    )
                }
                await MainActor.run {
                    missingStatus = "Deleted \(track.title)."
                    viewModel.reload(appDatabase: appDatabase)
                }
            } catch {
                await MainActor.run {
                    missingStatus = "Delete failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct PlaybackStatusView: View {
    @ObservedObject var controller: PlaybackController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(controller.currentItem?.title ?? "Not Playing")
                .font(.headline)
            if let artist = controller.currentItem?.artist {
                Text(artist)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button {
                    controller.previous()
                } label: {
                    Image(systemName: "backward.fill")
                }
                Button {
                    controller.togglePlayPause()
                } label: {
                    Image(systemName: controller.state == .playing ? "pause.fill" : "play.fill")
                }
                Button {
                    controller.next()
                } label: {
                    Image(systemName: "forward.fill")
                }

                Spacer()
                Text(timeLabel(current: controller.currentTime, duration: controller.duration))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func timeLabel(current: Double, duration: Double) -> String {
        "\(formatTime(current)) / \(formatTime(duration))"
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct PlaybackQueueSection: View {
    @ObservedObject var controller: PlaybackController

    var body: some View {
        Section("Queue") {
            if controller.queueItems.isEmpty {
                Text("Queue is empty")
            } else {
                ForEach(Array(controller.queueItems.enumerated()), id: \.offset) { index, item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.title)
                            if let artist = item.artist {
                                Text(artist)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if controller.currentItem?.id == item.id {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            controller.removeFromQueue(at: index)
                        } label: {
                            Text("Remove")
                        }
                    }
                }
                .onMove { offsets, destination in
                    controller.moveQueue(fromOffsets: offsets, toOffset: destination)
                }
                Button(role: .destructive) {
                    controller.clearQueue()
                } label: {
                    Text("Clear Queue")
                }
            }
        }
    }
}
#Preview {
    LibraryView(showsSettings: .constant(false), showsImport: .constant(false))
 }
