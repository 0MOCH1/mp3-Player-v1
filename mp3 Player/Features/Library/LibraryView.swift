import GRDB
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.playbackController) private var playbackController
    @StateObject private var viewModel = LibraryViewModel()
    @State private var activeImporter: ActiveImporter?
    @State private var isImporterPresented = false
    @State private var missingStatus: String?
    @State private var showsNowPlaying = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScrollPositionDetector()
                    
                    // Pinned section (favorites) - no label, 2 rows × 3 columns
                    if !viewModel.favoriteAlbums.isEmpty || !viewModel.favoritePlaylists.isEmpty {
                        let columns = [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ]
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.favoriteAlbums.prefix(6)) { album in
                                NavigationLink {
                                    AlbumDetailView(albumId: album.id, albumName: album.name)
                                } label: {
                                    AlbumTileView(
                                        title: album.name,
                                        artist: album.artist,
                                        artworkUri: album.artworkUri,
                                        isFavorite: album.isFavorite
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            ForEach(viewModel.favoritePlaylists.prefix(6 - min(6, viewModel.favoriteAlbums.count))) { playlist in
                                NavigationLink {
                                    PlaylistDetailView(playlistId: playlist.id, playlistName: playlist.name)
                                } label: {
                                    PlaylistTileView(
                                        title: playlist.name,
                                        artworkUris: playlist.artworkUris,
                                        isFavorite: playlist.isFavorite
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    // Browse section - no label
                    VStack(spacing: 0) {
                        NavigationLink {
                            PlaylistListView()
                        } label: {
                            HStack {
                                Label("Playlists", systemImage: "music.note.list")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                            .padding(.leading, 16)
                        
                        NavigationLink {
                            AlbumListView()
                        } label: {
                            HStack {
                                Label("Albums", systemImage: "square.stack")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                            .padding(.leading, 16)
                        
                        NavigationLink {
                            ArtistListView()
                        } label: {
                            HStack {
                                Label("Artists", systemImage: "music.mic")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                            .padding(.leading, 16)
                        
                        NavigationLink {
                            TrackListView()
                        } label: {
                            HStack {
                                Label("Tracks", systemImage: "music.note")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)

                    // Missing Files section - no label
                    if !viewModel.missingTracks.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.missingTracks.enumerated()), id: \.element.id) { index, track in
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
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
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
                                
                                if index < viewModel.missingTracks.count - 1 {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }

                            if let missingStatus {
                                Text(missingStatus)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }
                    
                    // Library statistics section - kept for future use but not displayed
                    // VStack {
                    //     Text("Albums: \(viewModel.counts.albums)")
                    //     Text("Artists: \(viewModel.counts.artists)")
                    //     Text("Tracks: \(viewModel.counts.tracks)")
                    //     Text("Playlists: \(viewModel.counts.playlists)")
                    // }
                }
                .padding(.bottom, 20)
            }
            .coordinateSpace(name: "scrollCoordinate")
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                guard let importer = activeImporter else { return }
                switch importer {
                case .relink(let track):
                    handleRelink(result, target: track)
                }
                activeImporter = nil
                isImporterPresented = false
            }
            .sheet(isPresented: $showsNowPlaying) {
                NowPlayingView()
            }
        }
        .appScreen()
        .onAppear {
            viewModel.loadIfNeeded(appDatabase: appDatabase)
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

private enum ActiveImporter {
    case relink(MissingTrackSummary)
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
    LibraryView()
}
