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
                // Recent Plays section - hidden but data is fetched
                // This section is prepared for future implementation with horizontal scroll and item snapping
                // Data fetching logic is maintained in viewModel
                
                // Recent Tracks section with 4 rows × variable columns
                Section {
                    if viewModel.recentTracks.isEmpty {
                        Text("No recent plays")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 0) {
                                // Create columns, each column has 4 rows
                                let tracks = Array(viewModel.recentTracks.prefix(20)) // Show up to 20 tracks (5 columns)
                                let columns = stride(from: 0, to: tracks.count, by: 4).map { index in
                                    Array(tracks[index..<min(index + 4, tracks.count)])
                                }
                                
                                ForEach(Array(columns.enumerated()), id: \.offset) { columnIndex, columnTracks in
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(columnTracks) { track in
                                            Button {
                                                playbackController.playFromHistory(
                                                    source: track.source,
                                                    sourceTrackId: track.sourceTrackId
                                                )
                                            } label: {
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
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                trackMenuItems(for: track)
                                            }
                                        }
                                    }
                                    .frame(width: 320) // Fixed width per column for snapping
                                }
                            }
                            .scrollTargetLayout() // Enable snapping
                        }
                        .scrollTargetBehavior(.viewAligned) // Snap to columns
                        .listRowInsets(EdgeInsets())
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
