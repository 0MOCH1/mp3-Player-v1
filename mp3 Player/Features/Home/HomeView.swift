import SwiftUI

struct HomeView: View {
    @Binding var showsSettings: Bool
    @Environment(\.appDatabase) private var appDatabase
    @EnvironmentObject private var playbackController: PlaybackController
    @StateObject private var viewModel = HomeViewModel()
    @State private var actionTrack: RecentTrackSummary?
    @State private var pendingDelete: TrackDeleteTarget?
    @State private var deleteError: String?
    @State private var showHeader = true
    private let headerHeight: CGFloat = 44

    var body: some View {
        NavigationStack {
            List {
                Spacer().frame(height: headerHeight).listRowSeparator(.hidden)

                recentSection
                recentPlaysSection
                topArtistsSection
            }
            .appList()
            
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Home")
                        .font(.largeTitle.weight(.semibold))
                }
                ToolbarItemGroup {
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    
                }
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
        }
        .appScreen()
        .onAppear {
            viewModel.loadIfNeeded(appDatabase: appDatabase)
        }
    }

    private var recentSection: some View {
        Section("Recent") {
            if viewModel.recentAlbums.isEmpty && viewModel.recentPlaylists.isEmpty {
                Text("No recent items")
                    .foregroundStyle(.secondary)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ]
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.recentAlbums) { album in
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
                    }
                    ForEach(viewModel.recentPlaylists) { playlist in
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
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
        }
    }

    private var recentPlaysSection: some View {
        Section("Recent Plays") {
            if viewModel.recentTracks.isEmpty {
                Text("No recent plays")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.recentTracks) { track in
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
    }

    private var topArtistsSection: some View {
        Section("Top Artists (30d)") {
            if viewModel.topArtists.isEmpty {
                Text("No top artists yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.topArtists) { artist in
                    Text(artist.name)
                }
            }
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
        TrackDeletionHelper.deleteTrack(
            target,
            appDatabase: appDatabase,
            playbackController: playbackController,
            onSuccess: {
                pendingDelete = nil
                viewModel.reload(appDatabase: appDatabase)
            },
            onError: { error in
                deleteError = error
            }
        )
    }
}

#Preview {
    HomeView(showsSettings: .constant(false))
}
