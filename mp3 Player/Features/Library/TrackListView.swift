import Combine
import GRDB
import SwiftUI

struct TrackListView: View {
    @Environment(\.appDatabase) private var appDatabase
    @EnvironmentObject private var playbackController: PlaybackController
    @Environment(\.editMode) private var editMode
    @StateObject private var viewModel = TrackListViewModel()
    @AppStorage("track_sort_field") private var sortFieldRaw = TrackSortField.title.rawValue
    @AppStorage("track_sort_order") private var sortOrderRaw = SortOrder.ascending.rawValue
    @State private var selection = Set<Int64>()
    @State private var showsPlaylistPicker = false
    @State private var pickerTrackIds: [Int64] = []
    @State private var actionTrack: TrackListItem?
    @State private var showsEditSheet = false
    @State private var editingTrackId: Int64?
    @State private var editWarning: String?
    @State private var pendingDelete: TrackDeleteTarget?
    @State private var deleteError: String?

    var body: some View {
        List(selection: $selection) {
            if viewModel.tracks.isEmpty {
                Text("No tracks yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.tracks) { track in
                    TrackRowView(
                        title: track.title,
                        subtitle: track.artist,
                        artworkUri: track.artworkUri,
                        trackNumber: nil,
                        isFavorite: track.isFavorite,
                        isNowPlaying: playbackController.currentItem?.id == track.id,
                        showsArtwork: true,
                        onPlay: {
                            if editMode?.wrappedValue.isEditing != true {
                                playTrack(track)
                            }
                        },
                        onMore: {
                            actionTrack = track
                        }
                    )
                    .listRowInsets(.init())
                    .listRowSeparator(.visible)
                    .tag(track.id)
                    .contextMenu {
                        trackMenuItems(for: track)
                    }
                    .swipeActions(edge: .leading) {
                        Button("Add to Queue") {
                            enqueueEnd(trackId: track.id)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDelete = TrackDeleteTarget(id: track.id, title: track.title)
                        } label: {
                            Text("Delete")
                        }
                    }
                }
            }
        }
        .appList()
        .navigationTitle("Tracks")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !selection.isEmpty {
                    Button("Add to Playlist") {
                        pickerTrackIds = Array(selection)
                        showsPlaylistPicker = true
                    }
                }
            }
            ToolbarItem {
                EditButton()
            }
            ToolbarItem {
                Menu {
                    Picker("Sort By", selection: $sortFieldRaw) {
                        ForEach(TrackSortField.allCases, id: \.rawValue) { field in
                            Text(label(for: field)).tag(field.rawValue)
                        }
                    }
                    Picker("Order", selection: $sortOrderRaw) {
                        ForEach(SortOrder.allCases, id: \.rawValue) { order in
                            Text(label(for: order)).tag(order.rawValue)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showsPlaylistPicker) {
            PlaylistPickerView(trackIds: pickerTrackIds, trackTitle: playlistPickerTitle)
        }
        .sheet(isPresented: $showsEditSheet, onDismiss: { editingTrackId = nil }) {
            if let editingTrackId {
                TrackMetadataEditorView(trackId: editingTrackId) {
                    reload()
                }
            }
        }
        .alert("Metadata Edit", isPresented: Binding(get: {
            editWarning != nil
        }, set: { newValue in
            if !newValue { editWarning = nil }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(editWarning ?? "")
        }
        .confirmationDialog(
            "Track Options",
            isPresented: Binding(get: { actionTrack != nil }, set: { newValue in
                if !newValue { actionTrack = nil }
            }),
            titleVisibility: .visible
        ) {
            if let track = actionTrack {
                trackMenuItems(for: track)
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
        .onAppear {
            reload()
        }
        .onChange(of: sortFieldRaw) { _, _ in
            reload()
        }
        .onChange(of: sortOrderRaw) { _, _ in
            reload()
        }
        .onChange(of: showsPlaylistPicker) { _, isPresented in
            if !isPresented {
                selection.removeAll()
            }
        }
        .appScreen()
    }

    @ViewBuilder
    private func trackMenuItems(for track: TrackListItem) -> some View {
        Button("Play Next") {
            enqueueNext(trackId: track.id)
        }
        Button("Add to Queue") {
            enqueueEnd(trackId: track.id)
        }
        Button("Add to Playlist") {
            pickerTrackIds = [track.id]
            showsPlaylistPicker = true
        }
        Button(track.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            toggleFavorite(trackId: track.id, isFavorite: track.isFavorite)
        }
        Button("Edit Metadata") {
            editMetadata(trackId: track.id)
        }
        Button(role: .destructive) {
            pendingDelete = TrackDeleteTarget(id: track.id, title: track.title)
        } label: {
            Text("Delete Track")
        }
    }

    private var playlistPickerTitle: String? {
        if pickerTrackIds.count == 1,
           let track = viewModel.tracks.first(where: { $0.id == pickerTrackIds[0] }) {
            return track.title
        }
        return "\(pickerTrackIds.count) tracks"
    }

    private func reload() {
        guard let appDatabase else { return }
        let sortField = TrackSortField(rawValue: sortFieldRaw) ?? .title
        let sortOrder = SortOrder(rawValue: sortOrderRaw) ?? .ascending
        viewModel.reload(appDatabase: appDatabase, sortField: sortField, sortOrder: sortOrder)
    }

    private func playTrack(_ track: TrackListItem) {
        guard let index = viewModel.trackIds.firstIndex(of: track.id) else { return }
        playbackController.setQueue(trackIds: viewModel.trackIds, startAt: index, playImmediately: true)
    }

    private func enqueueNext(trackId: Int64) {
        playbackController.enqueueNext(trackIds: [trackId])
    }

    private func enqueueEnd(trackId: Int64) {
        playbackController.enqueueEnd(trackIds: [trackId])
    }

    private func toggleFavorite(trackId: Int64, isFavorite: Bool) {
        guard let appDatabase else { return }
        let newValue = !isFavorite
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            try? await appDatabase.dbPool.write { db in
                try db.execute(
                    sql: "UPDATE tracks SET is_favorite = ?, updated_at = ? WHERE id = ?",
                    arguments: [newValue, now, trackId]
                )
            }
            await MainActor.run {
                reload()
            }
        }
    }

    private func editMetadata(trackId: Int64) {
        guard let appDatabase else { return }
        Task {
            let editable = await canEditTrack(trackId: trackId, appDatabase: appDatabase)
            await MainActor.run {
                if editable {
                    editingTrackId = trackId
                    showsEditSheet = true
                } else {
                    editWarning = "Metadata editing is available for app-copied files only."
                }
            }
        }
    }

    private func canEditTrack(trackId: Int64, appDatabase: AppDatabase) async -> Bool {
        let modeRaw = (try? await appDatabase.dbPool.read { db -> String? in
            try String.fetchOne(
                db,
                sql: """
                SELECT import_mode
                FROM import_records
                WHERE track_id = ?
                ORDER BY updated_at DESC
                LIMIT 1
                """,
                arguments: [trackId]
            )
        }) ?? nil
        guard let modeRaw else { return false }
        return modeRaw == ImportMode.copy.rawValue || modeRaw == ImportMode.copyThenDelete.rawValue
    }

    private func deleteTrack(_ target: TrackDeleteTarget) {
        guard let appDatabase else { return }
        let deletionService = TrackDeletionService(appDatabase: appDatabase)
        Task {
            do {
                _ = try await deletionService.deleteTrack(trackId: target.id)
                await MainActor.run {
                    playbackController.removeTrackFromQueue(trackId: target.id)
                    pendingDelete = nil
                    reload()
                }
            } catch {
                await MainActor.run {
                    deleteError = error.localizedDescription
                }
            }
        }
    }

    private func label(for field: TrackSortField) -> String {
        switch field {
        case .title:
            return "Title"
        case .addedDate:
            return "Added Date"
        case .artist:
            return "Artist"
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

private struct TrackListItem: Identifiable {
    let id: Int64
    let title: String
    let artist: String?
    let isFavorite: Bool
    let artworkUri: String?
}


@MainActor
private final class TrackListViewModel: ObservableObject {
    @Published var tracks: [TrackListItem] = []
    @Published var trackIds: [Int64] = []

    func reload(appDatabase: AppDatabase, sortField: TrackSortField, sortOrder: SortOrder) {
        Task {
            await loadData(appDatabase: appDatabase, sortField: sortField, sortOrder: sortOrder)
        }
    }

    private func loadData(appDatabase: AppDatabase, sortField: TrackSortField, sortOrder: SortOrder) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> [TrackListItem] in
            let direction = sortOrder == .ascending ? "ASC" : "DESC"
            let orderClause: String
            switch sortField {
            case .title:
                orderClause = "COALESCE(mo.title, t.title) COLLATE NOCASE \(direction)"
            case .addedDate:
                orderClause = "t.created_at \(direction)"
            case .artist:
                orderClause = "COALESCE(mo.artist_name, a.name) COLLATE NOCASE \(direction)"
            }

            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    t.id AS id,
                    COALESCE(mo.title, t.title) AS title,
                    COALESCE(mo.artist_name, a.name) AS artist_name,
                    t.is_favorite AS is_favorite,
                    aw.file_uri AS artwork_uri
                FROM tracks t
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN artists a ON a.id = t.artist_id
                LEFT JOIN artworks aw
                    ON aw.id = COALESCE(mo.artwork_id, t.artwork_id, t.album_artwork_id)
                ORDER BY \(orderClause), t.id DESC
                """
            )
            return rows.compactMap { row -> TrackListItem? in
                guard let id = row["id"] as Int64? else { return nil }
                let title = row["title"] as String? ?? "Unknown Title"
                let artist = row["artist_name"] as String?
                let isFavorite = row["is_favorite"] as Bool? ?? false
                let artworkUri = row["artwork_uri"] as String?
                return TrackListItem(
                    id: id,
                    title: title,
                    artist: artist,
                    isFavorite: isFavorite,
                    artworkUri: artworkUri
                )
            }
        }) ?? []

        tracks = snapshot
        trackIds = snapshot.map { $0.id }
    }
}

#Preview {
    NavigationStack {
        TrackListView()
    }
}
