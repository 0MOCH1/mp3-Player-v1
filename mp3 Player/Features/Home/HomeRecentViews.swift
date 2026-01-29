import SwiftUI

struct SectionHeaderLink<Destination: View>: View {
    let title: String
    let destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
    }
}

struct RecentTracksColumnGridView: View {
    let tracks: [RecentTrackSummary]

    @EnvironmentObject private var playbackController: PlaybackController

    private let rowsPerColumn = 4
    private let columnWidth: CGFloat = 160

    var body: some View {
        let columns = chunked(tracks: tracks, rows: rowsPerColumn)
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(column) { track in
                            Button {
                                playbackController.playFromHistory(
                                    source: track.source,
                                    sourceTrackId: track.sourceTrackId
                                )
                            } label: {
                                TrackTileView(
                                    title: track.title,
                                    artist: track.artist,
                                    artworkUri: track.artworkUri,
                                    isFavorite: track.isFavorite
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: columnWidth, alignment: .top)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private func chunked(tracks: [RecentTrackSummary], rows: Int) -> [[RecentTrackSummary]] {
        guard rows > 0 else { return [] }
        var columns: [[RecentTrackSummary]] = []
        var index = 0
        while index < tracks.count {
            let endIndex = min(index + rows, tracks.count)
            columns.append(Array(tracks[index..<endIndex]))
            index = endIndex
        }
        return columns
    }
}

struct RecentPlaysRowView: View {
    let items: [RecentPlayedItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(items) { item in
                    NavigationLink {
                        destinationView(for: item)
                    } label: {
                        tileView(for: item)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 160, alignment: .top)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    @ViewBuilder
    private func destinationView(for item: RecentPlayedItem) -> some View {
        switch item.kind {
        case .album:
            AlbumDetailView(albumId: item.id, albumName: item.name)
        case .playlist:
            PlaylistDetailView(playlistId: item.id, playlistName: item.name)
        }
    }

    @ViewBuilder
    private func tileView(for item: RecentPlayedItem) -> some View {
        switch item.kind {
        case .album:
            AlbumTileView(
                title: item.name,
                artist: item.albumArtist,
                artworkUri: item.artworkUri,
                isFavorite: item.isFavorite
            )
        case .playlist:
            PlaylistTileView(
                title: item.name,
                artworkUris: item.artworkUris,
                isFavorite: item.isFavorite
            )
        }
    }
}

struct RecentTracksListView: View {
    @ObservedObject var viewModel: HomeViewModel

    @Environment(\.appDatabase) private var appDatabase
    @EnvironmentObject private var playbackController: PlaybackController
    @State private var actionTrack: RecentTrackSummary?
    @State private var pendingDelete: TrackDeleteTarget?
    @State private var deleteError: String?

    var body: some View {
        List {
            if viewModel.recentTracks.isEmpty {
                Text("最近の曲がありません")
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
        .appList()
        .navigationTitle("最近の曲")
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

struct RecentTracksGridView: View {
    @ObservedObject var viewModel: HomeViewModel

    @Environment(\.appDatabase) private var appDatabase
    @EnvironmentObject private var playbackController: PlaybackController

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            if viewModel.recentTracks.isEmpty {
                Text("最近の曲がありません")
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.recentTracks) { track in
                        Button {
                            playbackController.playFromHistory(
                                source: track.source,
                                sourceTrackId: track.sourceTrackId
                            )
                        } label: {
                            TrackTileView(
                                title: track.title,
                                artist: track.artist,
                                artworkUri: track.artworkUri,
                                isFavorite: track.isFavorite
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("最近の曲")
        .appScreen()
        .onAppear {
            viewModel.loadIfNeeded(appDatabase: appDatabase)
        }
    }
}
