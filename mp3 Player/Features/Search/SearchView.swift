import SwiftUI

struct SearchView: View {
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.playbackController) private var playbackController
    @Environment(\.appleMusicService) private var appleMusicService
    @StateObject private var viewModel = SearchViewModel()
    @State private var query = ""
    @State private var scope: SearchScope = .local
    @State private var showsPlaylistPicker = false
    @State private var pickerTrackIds: [Int64] = []
    @State private var pendingDelete: TrackDeleteTarget?
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Source") {
                    Picker("Search Scope", selection: $scope) {
                        ForEach(SearchScope.allCases, id: \.self) { scope in
                            Text(scope.rawValue.capitalized).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if scope == .external {
                    Section("Apple Music") {
                        Text(viewModel.externalStatusMessage)
                            .foregroundStyle(.secondary)
                        if viewModel.externalCanRequest {
                            Button("Request Apple Music Access") {
                                viewModel.requestExternalAuthorization(appleMusicService)
                            }
                            .disabled(viewModel.externalIsRequesting)
                        }
                    }
                    if viewModel.externalIsAuthorized {
                        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Section("Results") {
                                Text("Type to search Apple Music.")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            externalResultsSections
                        }
                    } else {
                        Section("Results") {
                            Text("Apple Music authorization required.")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Results") {
                        Text("Type to search")
                    }
                } else {
                    resultsSections
                }
            }
            .appList()
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .onChange(of: query) { _, newValue in
                viewModel.updateQuery(newValue, scope: scope, appDatabase: appDatabase, appleMusicService: appleMusicService)
            }
            .onChange(of: scope) { _, newValue in
                viewModel.updateQuery(query, scope: newValue, appDatabase: appDatabase, appleMusicService: appleMusicService)
            }
            .onAppear {
                viewModel.updateQuery(query, scope: scope, appDatabase: appDatabase, appleMusicService: appleMusicService)
            }
            .sheet(isPresented: $showsPlaylistPicker) {
                PlaylistPickerView(trackIds: pickerTrackIds, trackTitle: playlistPickerTitle)
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
    }

    @ViewBuilder
    private var resultsSections: some View {
        Section("Artists") {
            if viewModel.artists.isEmpty {
                Text("No artists")
            } else {
                ForEach(viewModel.artists.prefix(5)) { artist in
                    NavigationLink(artist.name) {
                        ArtistDetailView(artistId: artist.id, artistName: artist.name)
                    }
                }
                if viewModel.artists.count > 5 {
                    NavigationLink("See all artists") {
                        SearchArtistResultsView(results: viewModel.artists)
                    }
                }
            }
        }

        Section("Albums") {
            if viewModel.albums.isEmpty {
                Text("No albums")
            } else {
                ForEach(viewModel.albums.prefix(5)) { album in
                    NavigationLink {
                        AlbumDetailView(albumId: album.id, albumName: album.name)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(album.name)
                            if let artist = album.albumArtist {
                                Text(artist)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if viewModel.albums.count > 5 {
                    NavigationLink("See all albums") {
                        SearchAlbumResultsView(results: viewModel.albums)
                    }
                }
            }
        }

        Section("Tracks") {
            if viewModel.tracks.isEmpty {
                Text("No tracks")
            } else {
                ForEach(viewModel.tracks.prefix(5)) { track in
                    Button {
                        playTrack(track, from: viewModel.tracks)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(track.title)
                            if let artist = track.artist {
                                Text(artist)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
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
                }
                if viewModel.tracks.count > 5 {
                    NavigationLink("See all tracks") {
                        SearchTrackResultsView(results: viewModel.tracks)
                    }
                }
            }
        }

        Section("Playlists") {
            if viewModel.playlists.isEmpty {
                Text("No playlists")
            } else {
                ForEach(viewModel.playlists.prefix(5)) { playlist in
                    NavigationLink(playlist.name) {
                        PlaylistDetailView(playlistId: playlist.id, playlistName: playlist.name)
                    }
                }
                if viewModel.playlists.count > 5 {
                    NavigationLink("See all playlists") {
                        SearchPlaylistResultsView(results: viewModel.playlists)
                    }
                }
            }
        }

        Section("Lyrics") {
            if viewModel.lyrics.isEmpty {
                Text("No lyrics matches")
            } else {
                ForEach(viewModel.lyrics.prefix(5)) { track in
                    Button {
                        playLyricsTrack(track, from: viewModel.lyrics)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(track.title)
                            if let artist = track.artist {
                                Text(artist)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if viewModel.lyrics.count > 5 {
                    NavigationLink("See all lyrics") {
                        SearchLyricsResultsView(results: viewModel.lyrics)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var externalResultsSections: some View {
        Section("Artists") {
            if viewModel.externalArtists.isEmpty {
                Text("No artists")
            } else {
                ForEach(viewModel.externalArtists.prefix(10)) { artist in
                    Text(artist.name)
                }
            }
        }

        Section("Albums") {
            if viewModel.externalAlbums.isEmpty {
                Text("No albums")
            } else {
                ForEach(viewModel.externalAlbums.prefix(10)) { album in
                    VStack(alignment: .leading) {
                        Text(album.name)
                        if let artist = album.artist {
                            Text(artist)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        Section("Tracks") {
            if viewModel.externalTracks.isEmpty {
                Text("No tracks")
            } else {
                ForEach(viewModel.externalTracks.prefix(10)) { track in
                    VStack(alignment: .leading) {
                        Text(track.title)
                        if let artist = track.artist {
                            Text(artist)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        Section("Playlists") {
            if viewModel.externalPlaylists.isEmpty {
                Text("No playlists")
            } else {
                ForEach(viewModel.externalPlaylists.prefix(10)) { playlist in
                    VStack(alignment: .leading) {
                        Text(playlist.name)
                        if let curator = playlist.curator {
                            Text(curator)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var playlistPickerTitle: String? {
        if pickerTrackIds.count == 1,
           let track = viewModel.tracks.first(where: { $0.id == pickerTrackIds[0] }) {
            return track.title
        }
        return "\(pickerTrackIds.count) tracks"
    }

    private func playTrack(_ track: SearchTrackResult, from list: [SearchTrackResult]) {
        guard let playbackController else { return }
        let ids = list.map { $0.id }
        guard let index = list.firstIndex(where: { $0.id == track.id }) else { return }
        playbackController.setQueue(
            trackIds: ids,
            startAt: index,
            playImmediately: true,
            sourceName: "Search Results",
            sourceType: .search
        )
    }

    private func playLyricsTrack(_ track: SearchLyricsResult, from list: [SearchLyricsResult]) {
        guard let playbackController else { return }
        let ids = list.map { $0.id }
        guard let index = list.firstIndex(where: { $0.id == track.id }) else { return }
        playbackController.setQueue(
            trackIds: ids,
            startAt: index,
            playImmediately: true,
            sourceName: "Search Results",
            sourceType: .search
        )
    }

    private func enqueueNext(trackId: Int64) {
        playbackController?.enqueueNext(trackIds: [trackId])
    }

    private func enqueueEnd(trackId: Int64) {
        playbackController?.enqueueEnd(trackIds: [trackId])
    }

    private func deleteTrack(_ target: TrackDeleteTarget) {
        guard let appDatabase else { return }
        let deletionService = TrackDeletionService(appDatabase: appDatabase)
        Task {
            do {
                _ = try await deletionService.deleteTrack(trackId: target.id)
                await MainActor.run {
                    playbackController?.removeTrackFromQueue(trackId: target.id)
                    pendingDelete = nil
                    viewModel.updateQuery(
                        query,
                        scope: scope,
                        appDatabase: appDatabase,
                        appleMusicService: appleMusicService
                    )
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
    SearchView()
}
