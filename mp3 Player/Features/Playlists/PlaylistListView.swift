import Combine
import GRDB
import SwiftUI

struct PlaylistListView: View {
    @Environment(\.appDatabase) private var appDatabase
    @StateObject private var viewModel = PlaylistListViewModel()
    @AppStorage("playlist_sort_field") private var sortFieldRaw = PlaylistSortField.title.rawValue
    @AppStorage("playlist_sort_order") private var sortOrderRaw = SortOrder.ascending.rawValue
    @AppStorage("playlist_favorites_first") private var favoritesFirst = false
    @State private var showsCreatePlaylist = false
    @State private var newPlaylistName = ""
    @State private var playlistToRename: PlaylistListItem?
    @State private var renameText = ""
    @State private var actionPlaylist: PlaylistListItem?
    @State private var playlistToDelete: PlaylistListItem?
    @State private var showsDeleteConfirm = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    FavoritesPlaylistView()
                } label: {
                    Label("Favorites", systemImage: "star.fill")
                }
            }

            Section {
                Button {
                    showsCreatePlaylist = true
                } label: {
                    Label("New Playlist", systemImage: "plus")
                }

                if viewModel.playlists.isEmpty {
                    Text("No playlists yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlistId: playlist.id, playlistName: playlist.name)
                        } label: {
                            PlaylistRowView(
                                title: playlist.name,
                                artworkUris: playlist.artworkUris,
                                isFavorite: playlist.isFavorite,
                                onMore: {
                                    actionPlaylist = playlist
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            playlistMenuItems(for: playlist)
                        }
                    }
                }
            } header: {
                Text("Playlists")
            }
        }
        .appList()
        .navigationTitle("Playlists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sortFieldRaw) {
                        ForEach(PlaylistSortField.allCases, id: \.rawValue) { field in
                            Text(label(for: field)).tag(field.rawValue)
                        }
                    }
                    Picker("Order", selection: $sortOrderRaw) {
                        ForEach(SortOrder.allCases, id: \.rawValue) { order in
                            Text(label(for: order)).tag(order.rawValue)
                        }
                    }
                    Toggle("Favorites First", isOn: $favoritesFirst)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .alert("New Playlist", isPresented: $showsCreatePlaylist) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Create") {
                createPlaylist()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Playlist", isPresented: Binding(
            get: { playlistToRename != nil },
            set: { isPresented in
                if !isPresented {
                    playlistToRename = nil
                    renameText = ""
                }
            }
        )) {
            TextField("Playlist name", text: $renameText)
            Button("Save") {
                renamePlaylist()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Playlist Options",
            isPresented: Binding(get: { actionPlaylist != nil }, set: { isPresented in
                if !isPresented { actionPlaylist = nil }
            }),
            titleVisibility: .visible
        ) {
            if let playlist = actionPlaylist {
                playlistMenuItems(for: playlist)
            }
        }
        .confirmationDialog(
            "Delete Playlist?",
            isPresented: $showsDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deletePlaylist()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let playlist = playlistToDelete {
                Text("This will delete \"\(playlist.name)\".")
            }
        }
        .onAppear {
            reload()
        }
        .onChange(of: sortFieldRaw) { _, _ in
            reload()
        }
        .onChange(of: sortOrderRaw) { _, _ in
            reload()
        }
        .onChange(of: favoritesFirst) { _, _ in
            reload()
        }
        .appScreen()
    }

    @ViewBuilder
    private func playlistMenuItems(for playlist: PlaylistListItem) -> some View {
        Button(playlist.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            toggleFavorite(playlistId: playlist.id, isFavorite: playlist.isFavorite)
        }
        Button("Rename") {
            playlistToRename = playlist
            renameText = playlist.name
        }
        Button(role: .destructive) {
            playlistToDelete = playlist
            showsDeleteConfirm = true
        } label: {
            Text("Delete")
        }
    }

    private func reload() {
        guard let appDatabase else { return }
        let sortField = PlaylistSortField(rawValue: sortFieldRaw) ?? .title
        let sortOrder = SortOrder(rawValue: sortOrderRaw) ?? .ascending
        viewModel.reload(
            appDatabase: appDatabase,
            sortField: sortField,
            sortOrder: sortOrder,
            favoritesFirst: favoritesFirst
        )
    }

    private func createPlaylist() {
        guard let appDatabase else { return }
        let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            _ = try? appDatabase.repositories.playlists.create(name: name, now: now)
            await MainActor.run {
                newPlaylistName = ""
                reload()
            }
        }
    }

    private func renamePlaylist() {
        guard let appDatabase, let playlist = playlistToRename else { return }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            try? appDatabase.repositories.playlists.rename(id: playlist.id, name: name, updatedAt: now)
            await MainActor.run {
                playlistToRename = nil
                renameText = ""
                reload()
            }
        }
    }

    private func deletePlaylist() {
        guard let appDatabase, let playlist = playlistToDelete else { return }
        Task {
            try? appDatabase.repositories.playlists.delete(id: playlist.id)
            await MainActor.run {
                playlistToDelete = nil
                reload()
            }
        }
    }

    private func toggleFavorite(playlistId: Int64, isFavorite: Bool) {
        guard let appDatabase else { return }
        let newValue = !isFavorite
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            try? await appDatabase.dbPool.write { db in
                try db.execute(
                    sql: "UPDATE playlists SET is_favorite = ?, updated_at = ? WHERE id = ?",
                    arguments: [newValue, now, playlistId]
                )
            }
            await MainActor.run {
                reload()
            }
        }
    }

    private func label(for field: PlaylistSortField) -> String {
        switch field {
        case .title:
            return "Title"
        case .createdDate:
            return "Created Date"
        case .lastPlayedDate:
            return "Last Played"
        case .updatedDate:
            return "Updated Date"
        }
    }

    private func label(for order: SortOrder) -> String {
        switch order {
        case .ascending:
            return "Ascending"
        case .descending:
            return "Descending"
        }
    }
}

private struct PlaylistListItem: Identifiable {
    let id: Int64
    let name: String
    let isFavorite: Bool
    let artworkUris: [String?]
}

@MainActor
private final class PlaylistListViewModel: ObservableObject {
    @Published var playlists: [PlaylistListItem] = []

    func reload(
        appDatabase: AppDatabase,
        sortField: PlaylistSortField,
        sortOrder: SortOrder,
        favoritesFirst: Bool
    ) {
        Task {
            await loadData(
                appDatabase: appDatabase,
                sortField: sortField,
                sortOrder: sortOrder,
                favoritesFirst: favoritesFirst
            )
        }
    }

    private func loadData(
        appDatabase: AppDatabase,
        sortField: PlaylistSortField,
        sortOrder: SortOrder,
        favoritesFirst: Bool
    ) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> [PlaylistListItem] in
            let direction = sortOrder == .ascending ? "ASC" : "DESC"
            let orderClause: String
            switch sortField {
            case .title:
                orderClause = "p.name COLLATE NOCASE \(direction)"
            case .createdDate:
                orderClause = "p.created_at \(direction)"
            case .lastPlayedDate:
                orderClause = "COALESCE(p.last_played_at, 0) \(direction)"
            case .updatedDate:
                orderClause = "p.updated_at \(direction)"
            }

            let favoriteClause = favoritesFirst ? "p.is_favorite DESC, " : ""
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    p.id AS id,
                    p.name AS name,
                    p.is_favorite AS is_favorite
                FROM playlists p
                ORDER BY \(favoriteClause)\(orderClause)
                """
            )
            let basePlaylists = rows.compactMap { row -> PlaylistListItem? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Untitled Playlist"
                let isFavorite = row["is_favorite"] as Bool? ?? false
                return PlaylistListItem(id: id, name: name, isFavorite: isFavorite, artworkUris: [])
            }
            let playlistIds = basePlaylists.map { $0.id }
            guard !playlistIds.isEmpty else { return basePlaylists }

            let placeholders = playlistIds.map { _ in "?" }.joined(separator: ",")
            let artworkRows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    pt.playlist_id AS playlist_id,
                    aw.file_uri AS artwork_uri
                FROM playlist_tracks pt
                JOIN tracks t ON t.id = pt.track_id
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN artworks aw
                    ON aw.id = COALESCE(mo.artwork_id, t.artwork_id, t.album_artwork_id)
                WHERE pt.playlist_id IN (\(placeholders))
                ORDER BY pt.playlist_id, pt.ord
                """,
                arguments: StatementArguments(playlistIds)
            )

            var artworkMap: [Int64: [String?]] = [:]
            for row in artworkRows {
                guard let playlistId = row["playlist_id"] as Int64? else { continue }
                var list = artworkMap[playlistId] ?? []
                if list.count >= 4 { continue }
                let uri = row["artwork_uri"] as String?
                list.append(uri)
                artworkMap[playlistId] = list
            }

            return basePlaylists.map { playlist in
                PlaylistListItem(
                    id: playlist.id,
                    name: playlist.name,
                    isFavorite: playlist.isFavorite,
                    artworkUris: artworkMap[playlist.id] ?? []
                )
            }
        }) ?? []

        playlists = snapshot
    }
}

#Preview {
    NavigationStack {
        PlaylistListView()
    }
}
