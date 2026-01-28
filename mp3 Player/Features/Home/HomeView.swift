import SwiftUI

struct HomeView: View {
    @Environment(\.appDatabase) private var appDatabase
    @EnvironmentObject private var playbackController: PlaybackController
    @StateObject private var viewModel = HomeViewModel()
    @State private var actionTrack: RecentTrackSummary?
    @State private var pendingDelete: TrackDeleteTarget?
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            List {
                // Recent Plays section with horizontal scrolling
                Section {
                    if viewModel.recentAlbums.isEmpty && viewModel.recentPlaylists.isEmpty {
                        Text("No recent items")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
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
                                        .frame(width: 160)
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
                                        .frame(width: 160)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .listRowInsets(EdgeInsets())
                    }
                } header: {
                    HStack {
                        Text("Recent")
                            .font(.title2)
                            .fontWeight(.bold)
                            .textCase(nil)
                        Spacer()
                        NavigationLink {
                            RecentPlaysListView()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // Recent Tracks section
                Section {
                    if viewModel.recentTracks.isEmpty {
                        Text("No recent plays")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.recentTracks.prefix(4)) { track in
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
                } header: {
                    HStack {
                        Text("Recent Tracks")
                            .font(.title2)
                            .fontWeight(.bold)
                            .textCase(nil)
                        Spacer()
                        NavigationLink {
                            RecentTracksListView()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

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
            .appList()
            .navigationTitle("Home")
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
        }
        .appScreen()
        .onAppear {
            viewModel.loadIfNeeded(appDatabase: appDatabase)
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
                    viewModel.reload(appDatabase: appDatabase)
                }
            } catch {
                await MainActor.run {
                    deleteError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
