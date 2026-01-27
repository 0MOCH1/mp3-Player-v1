import Combine
import GRDB
import SwiftUI

struct ArtistListView: View {
    @Environment(\.appDatabase) private var appDatabase
    @StateObject private var viewModel = ArtistListViewModel()
    @AppStorage("artist_favorites_first") private var favoritesFirst = false

    var body: some View {
        List {
            if viewModel.artists.isEmpty {
                Text("No artists yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.artists) { artist in
                    NavigationLink {
                        ArtistDetailView(artistId: artist.id, artistName: artist.name)
                    } label: {
                        HStack {
                            Text(artist.name)
                            Spacer()
                            if artist.isFavorite {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .contextMenu {
                        Button(artist.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                            toggleFavorite(artistId: artist.id, isFavorite: artist.isFavorite)
                        }
                    }
                }
            }
        }
        .appList()
        .navigationTitle("Artists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Favorites First", isOn: $favoritesFirst)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .onAppear {
            reload()
        }
        .onChange(of: favoritesFirst) { _, _ in
            reload()
        }
        .appScreen()
    }

    private func reload() {
        guard let appDatabase else { return }
        viewModel.reload(appDatabase: appDatabase, favoritesFirst: favoritesFirst)
    }

    private func toggleFavorite(artistId: Int64, isFavorite: Bool) {
        guard let appDatabase else { return }
        let newValue = !isFavorite
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            try? await appDatabase.dbPool.write { db in
                try db.execute(
                    sql: "UPDATE artists SET is_favorite = ?, updated_at = ? WHERE id = ?",
                    arguments: [newValue, now, artistId]
                )
            }
            await MainActor.run {
                reload()
            }
        }
    }
}

private struct ArtistSummary: Identifiable {
    let id: Int64
    let name: String
    let isFavorite: Bool
}

@MainActor
private final class ArtistListViewModel: ObservableObject {
    @Published var artists: [ArtistSummary] = []

    func reload(appDatabase: AppDatabase, favoritesFirst: Bool) {
        Task {
            await loadData(appDatabase: appDatabase, favoritesFirst: favoritesFirst)
        }
    }

    private func loadData(appDatabase: AppDatabase, favoritesFirst: Bool) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> [ArtistSummary] in
            let favoriteClause = favoritesFirst ? "a.is_favorite DESC, " : ""
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    a.id AS id,
                    a.name AS name,
                    a.is_favorite AS is_favorite
                FROM artists a
                ORDER BY \(favoriteClause)a.name COLLATE NOCASE
                """
            )
            return rows.compactMap { row -> ArtistSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Unknown Artist"
                let isFavorite = row["is_favorite"] as Bool? ?? false
                return ArtistSummary(id: id, name: name, isFavorite: isFavorite)
            }
        }) ?? []

        artists = snapshot
    }
}

private struct ArtistTrackSummary: Identifiable {
    let id: Int64
    let title: String
    let album: String?
    let artworkUri: String?
    let isFavorite: Bool
}

struct ArtistDetailView: View {
    let artistId: Int64
    let artistName: String

    @Environment(\.appDatabase) private var appDatabase
    @EnvironmentObject private var playbackController: PlaybackController
    @StateObject private var viewModel = ArtistDetailViewModel()
    @State private var showsEditSheet = false
    @State private var editingTrackId: Int64?
    @State private var editWarning: String?
    @State private var actionTrack: ArtistTrackSummary?
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
                        subtitle: track.album,
                        artworkUri: track.artworkUri,
                        trackNumber: nil,
                        isFavorite: track.isFavorite,
                        isNowPlaying: playbackController.currentItem?.id == track.id,
                        showsArtwork: true,
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
        .navigationTitle(artistName)
        .onAppear {
            viewModel.loadIfNeeded(artistId: artistId, appDatabase: appDatabase)
        }
        .sheet(isPresented: $showsEditSheet, onDismiss: { editingTrackId = nil }) {
            if let editingTrackId {
                TrackMetadataEditorView(trackId: editingTrackId) {
                    viewModel.reload(artistId: artistId, appDatabase: appDatabase)
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
    private func trackMenuItems(for track: ArtistTrackSummary) -> some View {
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
            sourceName: artistName,
            sourceType: .artist
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
                    viewModel.reload(artistId: artistId, appDatabase: appDatabase)
                }
            } catch {
                await MainActor.run {
                    deleteError = error.localizedDescription
                }
            }
        }
    }
}

@MainActor
private final class ArtistDetailViewModel: ObservableObject {
    @Published var tracks: [ArtistTrackSummary] = []
    @Published var trackIds: [Int64] = []

    private var didLoad = false

    func loadIfNeeded(artistId: Int64, appDatabase: AppDatabase?) {
        guard !didLoad, let appDatabase else { return }
        didLoad = true
        Task {
            await loadData(artistId: artistId, appDatabase: appDatabase)
        }
    }

    func reload(artistId: Int64, appDatabase: AppDatabase?) {
        guard let appDatabase else { return }
        Task {
            await loadData(artistId: artistId, appDatabase: appDatabase)
        }
    }

    private func loadData(artistId: Int64, appDatabase: AppDatabase) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> ([ArtistTrackSummary], [Int64]) in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    t.id AS id,
                    COALESCE(mo.title, t.title) AS title,
                    COALESCE(mo.album_name, al.name) AS album_name,
                    t.is_favorite AS is_favorite,
                    aw.file_uri AS artwork_uri
                FROM tracks t
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN albums al ON al.id = t.album_id
                LEFT JOIN artworks aw
                    ON aw.id = COALESCE(mo.artwork_id, t.artwork_id, t.album_artwork_id)
                WHERE t.artist_id = ?
                ORDER BY
                    COALESCE(mo.album_name, al.name) COLLATE NOCASE,
                    COALESCE(t.disc_number, 0),
                    COALESCE(t.track_number, 0),
                    COALESCE(mo.title, t.title) COLLATE NOCASE
                """,
                arguments: [artistId]
            )
            let summaries = rows.compactMap { row -> ArtistTrackSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let title = row["title"] as String? ?? "Unknown Title"
                let album = row["album_name"] as String?
                let artworkUri = row["artwork_uri"] as String?
                let isFavorite = row["is_favorite"] as Bool? ?? false
                return ArtistTrackSummary(
                    id: id,
                    title: title,
                    album: album,
                    artworkUri: artworkUri,
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
        ArtistListView()
    }
}
