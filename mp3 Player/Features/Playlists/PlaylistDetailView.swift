import Combine
import GRDB
import SwiftUI

struct PlaylistDetailView: View {
    let playlistId: Int64
    let playlistName: String

    @Environment(\.appDatabase) private var appDatabase
    @EnvironmentObject private var playbackController: PlaybackController
    @Environment(\.editMode) private var editMode
    @StateObject private var viewModel = PlaylistDetailViewModel()
    @AppStorage("playlist_track_sort_field") private var sortFieldRaw = PlaylistTrackSortField.manual.rawValue
    @AppStorage("playlist_track_sort_order") private var sortOrderRaw = SortOrder.ascending.rawValue
    @State private var showsTrackPicker = false
    @State private var showsAlbumPicker = false
    @State private var showsPlaylistPicker = false
    @State private var actionEntry: PlaylistTrackEntrySummary?
    @State private var pendingDelete: TrackDeleteTarget?
    @State private var deleteError: String?

    var body: some View {
        List {
            playlistHeader()
                .padding(.bottom, 16)
            Text("Playlist Description")
            playlistTracks()
            Text("Playlist Detail")
        }
        .appList()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if sortField == .manual {
                    EditButton()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add Tracks") {
                        showsTrackPicker = true
                    }
                    Button("Add Album") {
                        showsAlbumPicker = true
                    }
                    Button("Add Playlist") {
                        showsPlaylistPicker = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Order", selection: $sortFieldRaw) {
                        ForEach(PlaylistTrackSortField.allCases, id: \.rawValue) { field in
                            Text(label(for: field)).tag(field.rawValue)
                        }
                    }
                    if sortField != .manual {
                        Picker("Direction", selection: $sortOrderRaw) {
                            ForEach(SortOrder.allCases, id: \.rawValue) { order in
                                Text(label(for: order)).tag(order.rawValue)
                            }
                        }
                    }
                    Divider()
                    Button("Play Next") {
                        enqueueNext()
                    }
                    Button("Add to Queue") {
                        enqueueEnd()
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .confirmationDialog(
            "Track Options",
            isPresented: Binding(get: { actionEntry != nil }, set: { newValue in
                if !newValue { actionEntry = nil }
            }),
            titleVisibility: .visible
        ) {
            if let entry = actionEntry {
                playlistTrackMenuItems(for: entry)
            }
        }
        .confirmationDialog(
            "Delete Track?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { newValue in
                if !newValue { pendingDelete = nil }
            }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let target = pendingDelete {
                    deleteTrack(target)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Copied tracks delete the file; referenced tracks are removed from the library only.")
        }
        .alert("Delete Failed", isPresented: Binding(get: {
            deleteError != nil
        }, set: { newValue in
            if !newValue { deleteError = nil }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
        .sheet(isPresented: $showsTrackPicker) {
            TrackPickerView(playlistId: playlistId)
        }
        .sheet(isPresented: $showsAlbumPicker) {
            AlbumPickerView(playlistId: playlistId)
        }
        .sheet(isPresented: $showsPlaylistPicker) {
            PlaylistSourcePickerView(playlistId: playlistId)
        }
        .onAppear {
            reload()
        }
        .onChange(of: sortFieldRaw) { _, _ in
            reload()
        }
        .onChange(of: sortOrderRaw) { _, _ in
            reload()
        }
        .onChange(of: showsTrackPicker) { _, isPresented in
            if !isPresented {
                reload()
            }
        }
        .onChange(of: showsAlbumPicker) { _, isPresented in
            if !isPresented {
                reload()
            }
        }
        .onChange(of: showsPlaylistPicker) { _, isPresented in
            if !isPresented {
                reload()
            }
        }
        .appScreen()
    }

    @ViewBuilder
    private func playlistTrackMenuItems(for entry: PlaylistTrackEntrySummary) -> some View {
        Button(role: .destructive) {
            removeEntry(entry)
        } label: {
            Text("Remove")
        }
        Button(role: .destructive) {
            pendingDelete = TrackDeleteTarget(id: entry.trackId, title: entry.title)
        } label: {
            Text("Delete Track")
        }
    }

    @ViewBuilder
    private func playlistHeader() -> some View {
        if !viewModel.playlistArtworkUris.isEmpty {
            VStack {
                PlaylistCollageView(artworkUris: viewModel.playlistArtworkUris)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .frame(width: 270, height: 270)
                    .padding(.vertical, 4)
                Text(playlistName)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .padding(.vertical,  12)
                HStack(spacing: 16) {
                    CapsuleButtonView(
                        title: "Play",
                        systemImage: "play.fill"
                    ) {
                        playPlaylist()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 20)
                    CapsuleButtonView(
                        title: "Shuffle",
                        systemImage: "shuffle"
                    ) {
                        playShuffle()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowInsets(.init())
            .listRowSeparator(.hidden)
        }
    }
    
    @ViewBuilder
    private func playlistTracks() -> some View {
        if viewModel.entries.isEmpty {
            Text("No tracks yet")
                .foregroundStyle(.secondary)
        } else {
            ForEach(viewModel.entries) { entry in
                TrackRowView(
                    title: entry.title,
                    subtitle: entry.artist,
                    artworkUri: entry.artworkUri,
                    trackNumber: nil,
                    isFavorite: entry.isFavorite,
                    isNowPlaying: playbackController.currentItem?.id == entry.trackId,
                    showsArtwork: true,
                    onPlay: {
                        if editMode?.wrappedValue.isEditing != true {
                            playTrack(entryId: entry.id)
                        }
                    },
                    onMore: {
                        actionEntry = entry
                    }
                )
                .contextMenu {
                    playlistTrackMenuItems(for: entry)
                }
                .listRowInsets(.init())
                .listRowSeparator(.visible)
                .swipeActions(edge: .leading) {
                    Button("Add to Queue") {
                        playbackController.enqueueEnd(trackIds: [entry.trackId])
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        removeEntry(entry)
                    } label: {
                        Text("Remove")
                    }
                }
            }
            .onMove(perform: moveEntries)
        }
        
        Menu {
            Button {
                showsTrackPicker = true
            } label: { Label("Add Tracks", systemImage: "music.note") }
            Button {
                showsAlbumPicker = true
            } label: { Label("Add Album", systemImage: "square.stack") }
            Button {
                showsPlaylistPicker = true
            } label: { Label("Add Playlist", systemImage: "music.note.list") }
        } label: {
            GeneralRowView(title: "Add track")
        }
            .listRowInsets(.init())
            .listRowSeparator(.visible)
        
        
    }
    

    private var sortField: PlaylistTrackSortField {
        PlaylistTrackSortField(rawValue: sortFieldRaw) ?? .manual
    }

    private var sortOrder: SortOrder {
        SortOrder(rawValue: sortOrderRaw) ?? .ascending
    }

    private func reload() {
        guard let appDatabase else { return }
        viewModel.reload(
            playlistId: playlistId,
            appDatabase: appDatabase,
            sortField: sortField,
            sortOrder: sortOrder
        )
    }

    private func playTrack(entryId: Int) {
        guard let index = viewModel.entryIds.firstIndex(of: entryId) else { return }
        markPlayed()
        playbackController.setQueue(
            trackIds: viewModel.trackIds,
            startAt: index,
            playImmediately: true,
            sourceName: playlistName,
            sourceType: .playlist
        )
    }

    private func enqueueNext() {
        guard !viewModel.trackIds.isEmpty else { return }
        playbackController.enqueueNext(trackIds: viewModel.trackIds)
    }

    private func enqueueEnd() {
        guard !viewModel.trackIds.isEmpty else { return }
        playbackController.enqueueEnd(trackIds: viewModel.trackIds)
    }

    private func playPlaylist() {
        guard let firstEntry = viewModel.entries.first else { return }
        playTrack(entryId: firstEntry.id)
    }

    private func playShuffle() {
        guard !viewModel.trackIds.isEmpty else { return }
        markPlayed()
        playbackController.setQueue(
            trackIds: viewModel.trackIds.shuffled(),
            startAt: 0,
            playImmediately: true,
            sourceName: playlistName,
            sourceType: .playlist
        )
    }

    private func removeEntry(_ entry: PlaylistTrackEntrySummary) {
        guard let appDatabase else { return }
        Task {
            try? appDatabase.repositories.playlists.removeEntry(playlistId: playlistId, ord: entry.ord)
            await MainActor.run {
                reload()
            }
        }
    }

    private func deleteTrack(_ target: TrackDeleteTarget) {
        TrackDeletionHelper.deleteTrack(
            target,
            appDatabase: appDatabase,
            playbackController: playbackController,
            onSuccess: {
                pendingDelete = nil
                viewModel.reload(
                    playlistId: playlistId,
                    appDatabase: appDatabase,
                    sortField: sortField,
                    sortOrder: sortOrder
                )
            },
            onError: { error in
                deleteError = error
            }
        )
    }

    private func moveEntries(_ offsets: IndexSet, _ destination: Int) {
        guard sortField == .manual else { return }
        guard let appDatabase else { return }
        let updatedAt = Int64(Date().timeIntervalSince1970)
        Task {
            await viewModel.moveEntries(
                offsets,
                destination,
                playlistId: playlistId,
                appDatabase: appDatabase,
                updatedAt: updatedAt
            )
        }
    }

    private func markPlayed() {
        guard let appDatabase else { return }
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            try? appDatabase.repositories.playlists.markPlayed(playlistId: playlistId, playedAt: now)
        }
    }

    private func label(for field: PlaylistTrackSortField) -> String {
        switch field {
        case .manual:
            return "Manual"
        case .title:
            return "Title"
        case .artist:
            return "Artist"
        case .album:
            return "Album"
        case .releaseYear:
            return "Release Year"
        case .addedDate:
            return "Added Date"
        }
    }

    private func label(for order: SortOrder) -> String {
        switch order {
        case .ascending:
            return "Ascending"
        case .descending:
            return "Descending"
        }
    }
}

private struct PlaylistTrackEntrySummary: Identifiable {
    let id: Int
    let ord: Int
    let trackId: Int64
    let title: String
    let artist: String?
    let album: String?
    let releaseYear: Int?
    let addedAt: Int64
    let artworkUri: String?
    let isFavorite: Bool
}

@MainActor
private final class PlaylistDetailViewModel: ObservableObject {
    @Published var entries: [PlaylistTrackEntrySummary] = []
    @Published var trackIds: [Int64] = []
    @Published var entryIds: [Int] = []
    @Published var playlistArtworkUris: [String?] = []

    func reload(
        playlistId: Int64,
        appDatabase: AppDatabase?,
        sortField: PlaylistTrackSortField,
        sortOrder: SortOrder
    ) {
        guard let appDatabase else { return }
        Task {
            await loadData(
                playlistId: playlistId,
                appDatabase: appDatabase,
                sortField: sortField,
                sortOrder: sortOrder
            )
        }
    }

    func moveEntries(
        _ offsets: IndexSet,
        _ destination: Int,
        playlistId: Int64,
        appDatabase: AppDatabase,
        updatedAt: Int64
    ) async {
        var updated = entries
        updated.move(fromOffsets: offsets, toOffset: destination)
        let newEntries = updated.map { entry in
            PlaylistTrackEntry(trackId: entry.trackId, addedAt: entry.addedAt)
        }

        do {
            try appDatabase.repositories.playlists.updateOrder(
                playlistId: playlistId,
                entries: newEntries,
                updatedAt: updatedAt
            )
            await loadData(
                playlistId: playlistId,
                appDatabase: appDatabase,
                sortField: .manual,
                sortOrder: .ascending
            )
        } catch {
            // No-op; keep existing order on error.
        }
    }

    private func loadData(
        playlistId: Int64,
        appDatabase: AppDatabase,
        sortField: PlaylistTrackSortField,
        sortOrder: SortOrder
    ) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> [PlaylistTrackEntrySummary] in
            let direction = sortOrder == .ascending ? "ASC" : "DESC"
            let orderClause: String
            switch sortField {
            case .manual:
                orderClause = "pt.ord ASC"
            case .title:
                orderClause = "COALESCE(mo.title, t.title) COLLATE NOCASE \(direction)"
            case .artist:
                orderClause = "COALESCE(mo.artist_name, ar.name) COLLATE NOCASE \(direction)"
            case .album:
                orderClause = "COALESCE(mo.album_name, al.name) COLLATE NOCASE \(direction)"
            case .releaseYear:
                orderClause = "COALESCE(t.release_year, 0) \(direction)"
            case .addedDate:
                orderClause = "pt.added_at \(direction)"
            }

            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    pt.ord AS ord,
                    pt.added_at AS added_at,
                    t.id AS track_id,
                    COALESCE(mo.title, t.title) AS title,
                    COALESCE(mo.artist_name, ar.name) AS artist_name,
                    COALESCE(mo.album_name, al.name) AS album_name,
                    t.release_year AS release_year,
                    t.is_favorite AS is_favorite,
                    aw.file_uri AS artwork_uri
                FROM playlist_tracks pt
                JOIN tracks t ON t.id = pt.track_id
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN artists ar ON ar.id = t.artist_id
                LEFT JOIN albums al ON al.id = t.album_id
                LEFT JOIN artworks aw
                    ON aw.id = COALESCE(mo.artwork_id, t.artwork_id, t.album_artwork_id)
                WHERE pt.playlist_id = ?
                ORDER BY \(orderClause), pt.ord
                """,
                arguments: [playlistId]
            )
            return rows.compactMap { row -> PlaylistTrackEntrySummary? in
                guard let ord = row["ord"] as Int? else { return nil }
                guard let trackId = row["track_id"] as Int64? else { return nil }
                let title = row["title"] as String? ?? "Unknown Title"
                let artist = row["artist_name"] as String?
                let album = row["album_name"] as String?
                let releaseYear = row["release_year"] as Int?
                let addedAt = row["added_at"] as Int64? ?? 0
                let artworkUri = row["artwork_uri"] as String?
                let isFavorite = row["is_favorite"] as Bool? ?? false
                return PlaylistTrackEntrySummary(
                    id: ord,
                    ord: ord,
                    trackId: trackId,
                    title: title,
                    artist: artist,
                    album: album,
                    releaseYear: releaseYear,
                    addedAt: addedAt,
                    artworkUri: artworkUri,
                    isFavorite: isFavorite
                )
            }
        }) ?? []

        entries = snapshot
        playlistArtworkUris = Array(snapshot.prefix(4).map { $0.artworkUri })
        trackIds = snapshot.map { $0.trackId }
        entryIds = snapshot.map { $0.id }
    }
}

#Preview {
    PlaylistDetailView(playlistId: 1, playlistName: "Playlist")
}
