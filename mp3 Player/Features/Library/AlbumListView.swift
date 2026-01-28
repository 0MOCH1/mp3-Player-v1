import Combine
import GRDB
import SwiftUI

struct AlbumListView: View {
    @Environment(\.appDatabase) private var appDatabase
    @StateObject private var viewModel = AlbumListViewModel()
    @AppStorage("album_sort_field") private var sortFieldRaw = AlbumSortField.title.rawValue
    @AppStorage("album_sort_order") private var sortOrderRaw = SortOrder.ascending.rawValue
    @AppStorage("album_favorites_first") private var favoritesFirst = false

    var body: some View {
        ScrollView {
            if viewModel.albums.isEmpty {
                Text("No albums yet")
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ]
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.albums) { album in
                        NavigationLink {
                            AlbumDetailView(albumId: album.id, albumName: album.name)
                        } label: {
                            AlbumTileView(
                                title: album.name,
                                artist: album.albumArtist,
                                artworkUri: album.artworkUri,
                                isFavorite: album.isFavorite
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(album.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                                toggleFavorite(albumId: album.id, isFavorite: album.isFavorite)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Albums")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sortFieldRaw) {
                        ForEach(AlbumSortField.allCases, id: \.rawValue) { field in
                            Text(label(for: field)).tag(field.rawValue)
                        }
                    }
                    Picker("Order", selection: $sortOrderRaw) {
                        ForEach(SortOrder.allCases, id: \.rawValue) { order in
                            Text(label(for: order)).tag(order.rawValue)
                        }
                    }
                    Toggle("Favorites First", isOn: $favoritesFirst)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
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
        .onChange(of: favoritesFirst) { _, _ in
            reload()
        }
        .appScreen()
    }

    private func reload() {
        guard let appDatabase else { return }
        let sortField = AlbumSortField(rawValue: sortFieldRaw) ?? .title
        let sortOrder = SortOrder(rawValue: sortOrderRaw) ?? .ascending
        viewModel.reload(
            appDatabase: appDatabase,
            sortField: sortField,
            sortOrder: sortOrder,
            favoritesFirst: favoritesFirst
        )
    }

    private func toggleFavorite(albumId: Int64, isFavorite: Bool) {
        guard let appDatabase else { return }
        let newValue = !isFavorite
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            try? await appDatabase.dbPool.write { db in
                try db.execute(
                    sql: "UPDATE albums SET is_favorite = ?, updated_at = ? WHERE id = ?",
                    arguments: [newValue, now, albumId]
                )
            }
            await MainActor.run {
                reload()
            }
        }
    }

    private func label(for field: AlbumSortField) -> String {
        switch field {
        case .title:
            return "Title"
        case .addedDate:
            return "Added Date"
        case .artist:
            return "Artist"
        case .releaseYear:
            return "Release Year"
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

private struct AlbumSummary: Identifiable {
    let id: Int64
    let name: String
    let albumArtist: String?
    let isFavorite: Bool
    let artworkUri: String?
}

@MainActor
private final class AlbumListViewModel: ObservableObject {
    @Published var albums: [AlbumSummary] = []

    func reload(
        appDatabase: AppDatabase,
        sortField: AlbumSortField,
        sortOrder: SortOrder,
        favoritesFirst: Bool
    ) {
        Task {
            await loadData(
                appDatabase: appDatabase,
                sortField: sortField,
                sortOrder: sortOrder,
                favoritesFirst: favoritesFirst
            )
        }
    }

    private func loadData(
        appDatabase: AppDatabase,
        sortField: AlbumSortField,
        sortOrder: SortOrder,
        favoritesFirst: Bool
    ) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> [AlbumSummary] in
            let direction = sortOrder == .ascending ? "ASC" : "DESC"
            let orderClause: String
            switch sortField {
            case .title:
                orderClause = "al.name COLLATE NOCASE \(direction)"
            case .addedDate:
                orderClause = "al.created_at \(direction)"
            case .artist:
                orderClause = "COALESCE(ar.name, MIN(tr.name)) COLLATE NOCASE \(direction)"
            case .releaseYear:
                orderClause = "COALESCE(al.release_year, 0) \(direction)"
            }
            let favoriteClause = favoritesFirst ? "al.is_favorite DESC, " : ""

            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    al.id AS id,
                    al.name AS name,
                    COALESCE(ar.name, MIN(tr.name)) AS album_artist_name,
                    al.is_favorite AS is_favorite,
                    aw.file_uri AS artwork_uri
                FROM albums al
                LEFT JOIN artists ar ON ar.id = al.album_artist_id
                LEFT JOIN tracks t ON t.album_id = al.id
                LEFT JOIN artists tr ON tr.id = t.artist_id
                LEFT JOIN artworks aw ON aw.id = al.artwork_id
                GROUP BY al.id
                ORDER BY \(favoriteClause)\(orderClause)
                """
            )
            return rows.compactMap { row -> AlbumSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Unknown Album"
                let artist = row["album_artist_name"] as String?
                let isFavorite = row["is_favorite"] as Bool? ?? false
                let artworkUri = row["artwork_uri"] as String?
                return AlbumSummary(
                    id: id,
                    name: name,
                    albumArtist: artist,
                    isFavorite: isFavorite,
                    artworkUri: artworkUri
                )
            }
        }) ?? []

        albums = snapshot
    }
}

private struct AlbumTrackSummary: Identifiable {
    let id: Int64
    let title: String
    let artist: String?
    let trackNumber: Int?
    let isFavorite: Bool
}

struct AlbumDetailView: View {
    let albumId: Int64
    let albumName: String

    @Environment(\.appDatabase) private var appDatabase
    @EnvironmentObject private var playbackController: PlaybackController
    @StateObject private var viewModel = AlbumDetailViewModel()
    @State private var showsEditSheet = false
    @State private var editingTrackId: Int64?
    @State private var editWarning: String?
    @State private var actionTrack: AlbumTrackSummary?
    @State private var pendingDelete: TrackDeleteTarget?
    @State private var deleteError: String?

    var body: some View {
        List {
            if viewModel.tracks.isEmpty {
                Text("No tracks yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRowView(
                        title: track.title,
                        subtitle: track.artist,
                        artworkUri: nil,
                        trackNumber: track.trackNumber,
                        isFavorite: track.isFavorite,
                        isNowPlaying: playbackController.currentItem?.id == track.id,
                        showsArtwork: false,
                        onPlay: {
                            playTrack(at: index)
                        },
                        onMore: {
                            actionTrack = track
                        }
                    )
                    .contextMenu {
                        trackMenuItems(for: track)
                    }
                    .listRowInsets(.init())
                    .listRowSeparator(.visible)
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
        .navigationTitle(albumName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Play Next") {
                        enqueueNext()
                    }
                    Button("Add to Queue") {
                        enqueueEnd()
                    }
                } label: {
                    Image(systemName: "text.badge.plus")
                }
            }
        }
        .onAppear {
            viewModel.loadIfNeeded(albumId: albumId, appDatabase: appDatabase)
        }
        .sheet(isPresented: $showsEditSheet, onDismiss: { editingTrackId = nil }) {
            if let editingTrackId {
                TrackMetadataEditorView(trackId: editingTrackId) {
                    viewModel.reload(albumId: albumId, appDatabase: appDatabase)
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
        .appScreen()
    }

    @ViewBuilder
    private func trackMenuItems(for track: AlbumTrackSummary) -> some View {
        Button("Play Next") {
            enqueueNext(trackId: track.id)
        }
        Button("Add to Queue") {
            enqueueEnd(trackId: track.id)
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

    private func playTrack(at index: Int) {
        guard index < viewModel.trackIds.count else { return }
        playbackController.setQueue(
            trackIds: viewModel.trackIds,
            startAt: index,
            playImmediately: true,
            sourceName: albumName,
            sourceType: .album
        )
    }

    private func enqueueNext(trackId: Int64) {
        playbackController.enqueueNext(trackIds: [trackId])
    }

    private func enqueueEnd(trackId: Int64) {
        playbackController.enqueueEnd(trackIds: [trackId])
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
                    viewModel.reload(albumId: albumId, appDatabase: appDatabase)
                }
            } catch {
                await MainActor.run {
                    deleteError = error.localizedDescription
                }
            }
        }
    }

    private func enqueueNext() {
        guard !viewModel.trackIds.isEmpty else { return }
        playbackController.enqueueNext(trackIds: viewModel.trackIds)
    }

    private func enqueueEnd() {
        guard !viewModel.trackIds.isEmpty else { return }
        playbackController.enqueueEnd(trackIds: viewModel.trackIds)
    }
}

@MainActor
private final class AlbumDetailViewModel: ObservableObject {
    @Published var tracks: [AlbumTrackSummary] = []
    @Published var trackIds: [Int64] = []

    private var didLoad = false

    func loadIfNeeded(albumId: Int64, appDatabase: AppDatabase?) {
        guard !didLoad, let appDatabase else { return }
        didLoad = true
        Task {
            await loadData(albumId: albumId, appDatabase: appDatabase)
        }
    }

    func reload(albumId: Int64, appDatabase: AppDatabase?) {
        guard let appDatabase else { return }
        Task {
            await loadData(albumId: albumId, appDatabase: appDatabase)
        }
    }

    private func loadData(albumId: Int64, appDatabase: AppDatabase) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> ([AlbumTrackSummary], [Int64]) in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    t.id AS id,
                    COALESCE(mo.title, t.title) AS title,
                    COALESCE(mo.artist_name, ar.name) AS artist_name,
                    t.track_number AS track_number,
                    t.is_favorite AS is_favorite
                FROM tracks t
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN artists ar ON ar.id = t.artist_id
                WHERE t.album_id = ?
                ORDER BY
                    COALESCE(t.disc_number, 0),
                    COALESCE(t.track_number, 0),
                    t.title COLLATE NOCASE
                """,
                arguments: [albumId]
            )
            let summaries = rows.compactMap { row -> AlbumTrackSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let title = row["title"] as String? ?? "Unknown Title"
                let artist = row["artist_name"] as String?
                let trackNumber = row["track_number"] as Int?
                let isFavorite = row["is_favorite"] as Bool? ?? false
                return AlbumTrackSummary(
                    id: id,
                    title: title,
                    artist: artist,
                    trackNumber: trackNumber,
                    isFavorite: isFavorite
                )
            }
            return (summaries, summaries.map { $0.id })
        }) ?? ([], [])

        tracks = snapshot.0
        trackIds = snapshot.1
    }
}

#Preview {
    NavigationStack {
        AlbumListView()
    }
}
