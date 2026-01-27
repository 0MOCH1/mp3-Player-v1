import Combine
import SwiftUI

struct SearchArtistResultsView: View {
    let results: [SearchArtistResult]

    var body: some View {
        List {
            if results.isEmpty {
                Text("No artists")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { artist in
                    NavigationLink(artist.name) {
                        ArtistDetailView(artistId: artist.id, artistName: artist.name)
                    }
                }
            }
        }
        .appList()
        .navigationTitle("Artists")
        .appScreen()
    }
}

struct SearchAlbumResultsView: View {
    let results: [SearchAlbumResult]

    var body: some View {
        ScrollView {
            if results.isEmpty {
                Text("No albums")
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ]
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(results) { album in
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
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Albums")
        .appScreen()
    }
}

struct SearchPlaylistResultsView: View {
    let results: [SearchPlaylistResult]

    var body: some View {
        ScrollView {
            if results.isEmpty {
                Text("No playlists")
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ]
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(results) { playlist in
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
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Playlists")
        .appScreen()
    }
}

struct SearchTrackResultsView: View {
    let results: [SearchTrackResult]

    @EnvironmentObject private var playbackController: PlaybackController
    @Environment(\.appDatabase) private var appDatabase
    @State private var showsPlaylistPicker = false
    @State private var pickerTrackIds: [Int64] = []
    @State private var actionTrack: SearchTrackResult?
    @State private var pendingDelete: TrackDeleteTarget?
    @State private var deleteError: String?

    var body: some View {
        List {
            if results.isEmpty {
                Text("No tracks")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { track in
                    TrackRowView(
                        title: track.title,
                        subtitle: track.artist,
                        artworkUri: track.artworkUri,
                        trackNumber: nil,
                        isFavorite: track.isFavorite,
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
        .sheet(isPresented: $showsPlaylistPicker) {
            PlaylistPickerView(trackIds: pickerTrackIds, trackTitle: playlistPickerTitle)
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
    private func trackMenuItems(for track: SearchTrackResult) -> some View {
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
        Button(role: .destructive) {
            pendingDelete = TrackDeleteTarget(id: track.id, title: track.title)
        } label: {
            Text("Delete Track")
        }
    }

    private var playlistPickerTitle: String? {
        if pickerTrackIds.count == 1,
           let track = results.first(where: { $0.id == pickerTrackIds[0] }) {
            return track.title
        }
        return "\(pickerTrackIds.count) tracks"
    }

    private func playTrack(_ track: SearchTrackResult) {
        let ids = results.map { $0.id }
        guard let index = results.firstIndex(where: { $0.id == track.id }) else { return }
        playbackController.setQueue(
            trackIds: ids,
            startAt: index,
            playImmediately: true,
            sourceName: "Search Results",
            sourceType: .search
        )
    }

    private func enqueueNext(trackId: Int64) {
        playbackController.enqueueNext(trackIds: [trackId])
    }

    private func enqueueEnd(trackId: Int64) {
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
                }
            } catch {
                await MainActor.run {
                    deleteError = error.localizedDescription
                }
            }
        }
    }
}

struct SearchLyricsResultsView: View {
    let results: [SearchLyricsResult]

    @EnvironmentObject private var playbackController: PlaybackController
    @State private var actionTrack: SearchLyricsResult?

    var body: some View {
        List {
            if results.isEmpty {
                Text("No lyrics matches")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { track in
                    TrackRowView(
                        title: track.title,
                        subtitle: track.artist,
                        artworkUri: track.artworkUri,
                        trackNumber: nil,
                        isFavorite: false,
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
                        lyricsMenuItems(for: track)
                    }
                    .swipeActions(edge: .leading) {
                        Button("Add to Queue") {
                            enqueueEnd(trackId: track.id)
                        }
                    }
                }
            }
        }
        .appList()
        .navigationTitle("Lyrics")
        .confirmationDialog(
            "Track Options",
            isPresented: Binding(get: { actionTrack != nil }, set: { newValue in
                if !newValue { actionTrack = nil }
            }),
            titleVisibility: .visible
        ) {
            if let track = actionTrack {
                lyricsMenuItems(for: track)
            }
        }
        .appScreen()
    }

    @ViewBuilder
    private func lyricsMenuItems(for track: SearchLyricsResult) -> some View {
        Button("Play Next") {
            enqueueNext(trackId: track.id)
        }
        Button("Add to Queue") {
            enqueueEnd(trackId: track.id)
        }
    }

    private func playTrack(_ track: SearchLyricsResult) {
        let ids = results.map { $0.id }
        guard let index = results.firstIndex(where: { $0.id == track.id }) else { return }
        playbackController.setQueue(
            trackIds: ids,
            startAt: index,
            playImmediately: true,
            sourceName: "Search Results",
            sourceType: .search
        )
    }

    private func enqueueNext(trackId: Int64) {
        playbackController.enqueueNext(trackIds: [trackId])
    }

    private func enqueueEnd(trackId: Int64) {
        playbackController.enqueueEnd(trackIds: [trackId])
    }
}

#Preview {
    NavigationStack {
        SearchTrackResultsView(results: [])
    }
}
