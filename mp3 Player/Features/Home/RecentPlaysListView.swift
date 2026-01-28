import SwiftUI

struct RecentPlaysListView: View {
    @Environment(\.appDatabase) private var appDatabase
    @State private var albums: [RecentAlbumSummary] = []
    @State private var playlists: [RecentPlaylistSummary] = []
    
    var body: some View {
        List {
            if albums.isEmpty && playlists.isEmpty {
                Text("No recent plays")
                    .foregroundStyle(.secondary)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ]
                
                Section {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(albums) { album in
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
                        
                        ForEach(playlists) { playlist in
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
        .appList()
        .navigationTitle("Recent Plays")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        guard let appDatabase else { return }
        let viewModel = HomeViewModel()
        let (loadedAlbums, loadedPlaylists) = await viewModel.loadAllRecentPlays(appDatabase: appDatabase)
        albums = loadedAlbums
        playlists = loadedPlaylists
    }
}

#Preview {
    NavigationStack {
        RecentPlaysListView()
    }
}
