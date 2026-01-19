import Combine
import GRDB
import SwiftUI

struct AlbumArtistListView: View {
    @Environment(\.appDatabase) private var appDatabase
    @StateObject private var viewModel = AlbumArtistListViewModel()
    @AppStorage("album_artist_favorites_first") private var favoritesFirst = false

    var body: some View {
        List {
            if viewModel.artists.isEmpty {
                Text("No album artists yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.artists) { artist in
                    NavigationLink {
                        AlbumArtistDetailView(
                            albumArtistId: artist.id,
                            albumArtistName: artist.name
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(artist.name)
                                Text("\(artist.albumCount) albums")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
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
        .navigationTitle("Album Artists")
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

private struct AlbumArtistSummary: Identifiable {
    let id: Int64
    let name: String
    let albumCount: Int
    let isFavorite: Bool
}

@MainActor
private final class AlbumArtistListViewModel: ObservableObject {
    @Published var artists: [AlbumArtistSummary] = []

    func reload(appDatabase: AppDatabase, favoritesFirst: Bool) {
        Task {
            await loadData(appDatabase: appDatabase, favoritesFirst: favoritesFirst)
        }
    }

    private func loadData(appDatabase: AppDatabase, favoritesFirst: Bool) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> [AlbumArtistSummary] in
            let favoriteClause = favoritesFirst ? "ar.is_favorite DESC, " : ""
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    ar.id AS id,
                    ar.name AS name,
                    ar.is_favorite AS is_favorite,
                    COUNT(al.id) AS album_count
                FROM albums al
                JOIN artists ar ON ar.id = al.album_artist_id
                GROUP BY ar.id
                ORDER BY \(favoriteClause)ar.name COLLATE NOCASE
                """
            )
            return rows.compactMap { row -> AlbumArtistSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Unknown Artist"
                let albumCount = row["album_count"] as Int? ?? 0
                let isFavorite = row["is_favorite"] as Bool? ?? false
                return AlbumArtistSummary(
                    id: id,
                    name: name,
                    albumCount: albumCount,
                    isFavorite: isFavorite
                )
            }
        }) ?? []

        artists = snapshot
    }
}

private struct AlbumArtistAlbumSummary: Identifiable {
    let id: Int64
    let name: String
    let releaseYear: Int?
    let artworkUri: String?
    let isFavorite: Bool
}

struct AlbumArtistDetailView: View {
    let albumArtistId: Int64
    let albumArtistName: String

    @Environment(\.appDatabase) private var appDatabase
    @StateObject private var viewModel = AlbumArtistDetailViewModel()

    var body: some View {
        ScrollView {
            if viewModel.albums.isEmpty {
                Text("No albums yet")
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ]
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.albums) { album in
                        NavigationLink {
                            AlbumDetailView(albumId: album.id, albumName: album.name)
                        } label: {
                            AlbumTileView(
                                title: album.name,
                                artist: albumArtistName,
                                artworkUri: album.artworkUri,
                                isFavorite: album.isFavorite
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(album.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                                toggleFavorite(albumId: album.id, isFavorite: album.isFavorite)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(albumArtistName)
        .onAppear {
            reload()
        }
        .appScreen()
    }

    private func reload() {
        guard let appDatabase else { return }
        viewModel.reload(albumArtistId: albumArtistId, appDatabase: appDatabase)
    }

    private func toggleFavorite(albumId: Int64, isFavorite: Bool) {
        guard let appDatabase else { return }
        let newValue = !isFavorite
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            try? await appDatabase.dbPool.write { db in
                try db.execute(
                    sql: "UPDATE albums SET is_favorite = ?, updated_at = ? WHERE id = ?",
                    arguments: [newValue, now, albumId]
                )
            }
            await MainActor.run {
                reload()
            }
        }
    }
}

@MainActor
private final class AlbumArtistDetailViewModel: ObservableObject {
    @Published var albums: [AlbumArtistAlbumSummary] = []

    func reload(albumArtistId: Int64, appDatabase: AppDatabase) {
        Task {
            await loadData(albumArtistId: albumArtistId, appDatabase: appDatabase)
        }
    }

    private func loadData(albumArtistId: Int64, appDatabase: AppDatabase) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> [AlbumArtistAlbumSummary] in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    al.id AS id,
                    al.name AS name,
                    al.release_year AS release_year,
                    al.is_favorite AS is_favorite,
                    aw.file_uri AS artwork_uri
                FROM albums al
                LEFT JOIN artworks aw ON aw.id = al.artwork_id
                WHERE al.album_artist_id = ?
                ORDER BY al.name COLLATE NOCASE
                """,
                arguments: [albumArtistId]
            )
            return rows.compactMap { row -> AlbumArtistAlbumSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Unknown Album"
                let releaseYear = row["release_year"] as Int?
                let artworkUri = row["artwork_uri"] as String?
                let isFavorite = row["is_favorite"] as Bool? ?? false
                return AlbumArtistAlbumSummary(
                    id: id,
                    name: name,
                    releaseYear: releaseYear,
                    artworkUri: artworkUri,
                    isFavorite: isFavorite
                )
            }
        }) ?? []

        albums = snapshot
    }
}

#Preview {
    NavigationStack {
        AlbumArtistListView()
    }
}
