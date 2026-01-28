import SwiftUI

struct RecentTracksListView: View {
    @Environment(\.appDatabase) private var appDatabase
    @EnvironmentObject private var playbackController: PlaybackController
    @State private var tracks: [RecentTrackSummary] = []
    @State private var actionTrack: RecentTrackSummary?
    @State private var pendingDelete: TrackDeleteTarget?
    @State private var deleteError: String?
    
    var body: some View {
        List {
            if tracks.isEmpty {
                Text("No recent tracks")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tracks) { track in
                    TrackRowView(
                        title: track.title,
                        subtitle: track.artist,
                        artworkUri: track.artworkUri,
                        trackNumber: nil,
                        isFavorite: track.isFavorite,
                        isNowPlaying: track.trackId == playbackController.currentItem?.id,
                        showsArtwork: true,
                        onPlay: {
                            playbackController.playFromHistory(
                                source: track.source,
                                sourceTrackId: track.sourceTrackId
                            )
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
                            enqueueEnd(track)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            if let trackId = track.trackId {
                                pendingDelete = TrackDeleteTarget(id: trackId, title: track.title)
                            }
                        } label: {
                            Text("Delete")
                        }
                    }
                }
            }
        }
        .appList()
        .navigationTitle("Recent Tracks")
        .navigationBarTitleDisplayMode(.inline)
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
        .task {
            await loadData()
        }
    }
    
    @ViewBuilder
    private func trackMenuItems(for track: RecentTrackSummary) -> some View {
        Button("Play Next") {
            if let trackId = track.trackId {
                playbackController.enqueueNext(trackIds: [trackId])
            }
        }
        Button("Add to Queue") {
            enqueueEnd(track)
        }
    }
    
    private func enqueueEnd(_ track: RecentTrackSummary) {
        guard let trackId = track.trackId else { return }
        playbackController.enqueueEnd(trackIds: [trackId])
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
                    // Reload tracks
                    Task {
                        await loadData()
                    }
                }
            } catch {
                await MainActor.run {
                    deleteError = error.localizedDescription
                }
            }
        }
    }
    
    private func loadData() async {
        guard let appDatabase else { return }
        let viewModel = HomeViewModel()
        let loadedTracks = await viewModel.loadAllRecentTracks(appDatabase: appDatabase)
        tracks = loadedTracks
    }
}

#Preview {
    NavigationStack {
        RecentTracksListView()
    }
}
