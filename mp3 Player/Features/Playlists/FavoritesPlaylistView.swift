import Combine
import GRDB
import SwiftUI

struct FavoritesPlaylistView: View {
    @Environment(\.appDatabase) private var appDatabase
    @EnvironmentObject private var playbackController: PlaybackController
    @StateObject private var viewModel = FavoritesPlaylistViewModel()
    @State private var actionTrack: FavoriteTrackItem?
    @State private var pendingDelete: TrackDeleteTarget?
    @State private var deleteError: String?

    var body: some View {
        List {
            if viewModel.tracks.isEmpty {
                Text("No favorites yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.tracks) { track in
                    TrackRowView(
                        title: track.title,
                        subtitle: track.artist,
                        artworkUri: track.artworkUri,
                        trackNumber: nil,
                        isFavorite: true,
                        isNowPlaying: playbackController.currentItem?.id == track.id,
                        showsArtwork: true,
                        onPlay: {
                            playTrack(track)
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
                            toggleFavorite(trackId: track.id)
                        } label: {
                            Text("Remove")
                        }
                    }
                }
            }
        }
        .appList()
        .navigationTitle("Favorites")
        .onAppear {
            reload()
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
    private func trackMenuItems(for track: FavoriteTrackItem) -> some View {
        Button("Play Next") {
            enqueueNext(trackId: track.id)
        }
        Button("Add to Queue") {
            enqueueEnd(trackId: track.id)
        }
        Button("Remove from Favorites") {
            toggleFavorite(trackId: track.id)
        }
        Button(role: .destructive) {
            pendingDelete = TrackDeleteTarget(id: track.id, title: track.title)
        } label: {
            Text("Delete Track")
        }
    }

    private func reload() {
        guard let appDatabase else { return }
        viewModel.reload(appDatabase: appDatabase)
    }

    private func playTrack(_ track: FavoriteTrackItem) {
        guard let index = viewModel.trackIds.firstIndex(of: track.id) else { return }
        playbackController.setQueue(
            trackIds: viewModel.trackIds,
            startAt: index,
            playImmediately: true,
            sourceName: "Favorites",
            sourceType: .playlist
        )
    }

    private func enqueueNext(trackId: Int64) {
        playbackController.enqueueNext(trackIds: [trackId])
    }

    private func enqueueEnd(trackId: Int64) {
        playbackController.enqueueEnd(trackIds: [trackId])
    }

    private func toggleFavorite(trackId: Int64) {
        guard let appDatabase else { return }
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            try? await appDatabase.dbPool.write { db in
                try db.execute(
                    sql: "UPDATE tracks SET is_favorite = 0, updated_at = ? WHERE id = ?",
                    arguments: [now, trackId]
                )
            }
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
                reload()
            },
            onError: { error in
                deleteError = error
            }
        )
    }
}

private struct FavoriteTrackItem: Identifiable {
    let id: Int64
    let title: String
    let artist: String?
    let artworkUri: String?
}

@MainActor
private final class FavoritesPlaylistViewModel: ObservableObject {
    @Published var tracks: [FavoriteTrackItem] = []
    @Published var trackIds: [Int64] = []

    func reload(appDatabase: AppDatabase) {
        Task {
            await loadData(appDatabase: appDatabase)
        }
    }

    private func loadData(appDatabase: AppDatabase) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> [FavoriteTrackItem] in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    t.id AS id,
                    COALESCE(mo.title, t.title) AS title,
                    COALESCE(mo.artist_name, a.name) AS artist_name,
                    aw.file_uri AS artwork_uri
                FROM tracks t
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN artists a ON a.id = t.artist_id
                LEFT JOIN artworks aw
                    ON aw.id = COALESCE(mo.artwork_id, t.artwork_id, t.album_artwork_id)
                WHERE t.is_favorite = 1
                ORDER BY t.updated_at DESC
                """
            )
            return rows.compactMap { row -> FavoriteTrackItem? in
                guard let id = row["id"] as Int64? else { return nil }
                let title = row["title"] as String? ?? "Unknown Title"
                let artist = row["artist_name"] as String?
                let artworkUri = row["artwork_uri"] as String?
                return FavoriteTrackItem(
                    id: id,
                    title: title,
                    artist: artist,
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
        FavoritesPlaylistView()
    }
}
