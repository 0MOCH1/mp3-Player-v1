import Combine
import GRDB
import SwiftUI

struct TrackPickerView: View {
    let playlistId: Int64

    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TrackPickerViewModel()
    @State private var selection = Set<Int64>()
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                if viewModel.tracks.isEmpty {
                    Text("No tracks yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.tracks) { track in
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

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .appList()
            .navigationTitle("Add Tracks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        addSelected()
                    }
                    .disabled(selection.isEmpty)
                }
            }
            .onAppear {
                reload()
            }
        }
        .appScreen()
    }

    private func reload() {
        guard let appDatabase else { return }
        viewModel.reload(appDatabase: appDatabase)
    }

    private func addSelected() {
        guard let appDatabase else { return }
        let now = Int64(Date().timeIntervalSince1970)
        let ordered = viewModel.tracks.filter { selection.contains($0.id) }.map { $0.id }
        Task {
            do {
                try appDatabase.repositories.playlists.addTracks(
                    playlistId: playlistId,
                    trackIds: ordered,
                    position: nil,
                    addedAt: now
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Failed to add tracks."
                }
            }
        }
    }
}

private struct TrackPickerItem: Identifiable {
    let id: Int64
    let title: String
    let artist: String?
}

@MainActor
private final class TrackPickerViewModel: ObservableObject {
    @Published var tracks: [TrackPickerItem] = []

    func reload(appDatabase: AppDatabase) {
        Task {
            await loadData(appDatabase: appDatabase)
        }
    }

    private func loadData(appDatabase: AppDatabase) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> [TrackPickerItem] in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    t.id AS id,
                    COALESCE(mo.title, t.title) AS title,
                    COALESCE(mo.artist_name, a.name) AS artist_name
                FROM tracks t
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                LEFT JOIN artists a ON a.id = t.artist_id
                ORDER BY COALESCE(mo.title, t.title) COLLATE NOCASE
                """
            )
            return rows.compactMap { row -> TrackPickerItem? in
                guard let id = row["id"] as Int64? else { return nil }
                let title = row["title"] as String? ?? "Unknown Title"
                let artist = row["artist_name"] as String?
                return TrackPickerItem(id: id, title: title, artist: artist)
            }
        }) ?? []

        tracks = snapshot
    }
}

struct AlbumPickerView: View {
    let playlistId: Int64

    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AlbumPickerViewModel()
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.albums.isEmpty {
                    Text("No albums yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.albums) { album in
                        Button {
                            addAlbum(albumId: album.id)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(album.name)
                                if let artist = album.artist {
                                    Text(artist)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .appList()
            .navigationTitle("Add Album")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                reload()
            }
        }
        .appScreen()
    }

    private func reload() {
        guard let appDatabase else { return }
        viewModel.reload(appDatabase: appDatabase)
    }

    private func addAlbum(albumId: Int64) {
        guard let appDatabase else { return }
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            do {
                let trackIds = try await appDatabase.dbPool.read { db -> [Int64] in
                    let rows = try Row.fetchAll(
                        db,
                        sql: """
                        SELECT id
                        FROM tracks
                        WHERE album_id = ?
                        ORDER BY
                            COALESCE(disc_number, 0),
                            COALESCE(track_number, 0),
                            title COLLATE NOCASE
                        """,
                        arguments: [albumId]
                    )
                    return rows.compactMap { $0["id"] }
                }
                try appDatabase.repositories.playlists.addTracks(
                    playlistId: playlistId,
                    trackIds: trackIds,
                    position: nil,
                    addedAt: now
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Failed to add album."
                }
            }
        }
    }
}

private struct AlbumPickerItem: Identifiable {
    let id: Int64
    let name: String
    let artist: String?
}

@MainActor
private final class AlbumPickerViewModel: ObservableObject {
    @Published var albums: [AlbumPickerItem] = []

    func reload(appDatabase: AppDatabase) {
        Task {
            await loadData(appDatabase: appDatabase)
        }
    }

    private func loadData(appDatabase: AppDatabase) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> [AlbumPickerItem] in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    al.id AS id,
                    al.name AS name,
                    ar.name AS artist_name
                FROM albums al
                LEFT JOIN artists ar ON ar.id = al.album_artist_id
                ORDER BY al.name COLLATE NOCASE
                """
            )
            return rows.compactMap { row -> AlbumPickerItem? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Unknown Album"
                let artist = row["artist_name"] as String?
                return AlbumPickerItem(id: id, name: name, artist: artist)
            }
        }) ?? []

        albums = snapshot
    }
}

struct PlaylistSourcePickerView: View {
    let playlistId: Int64

    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PlaylistSourcePickerViewModel()
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.playlists.isEmpty {
                    Text("No playlists yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.playlists) { playlist in
                        Button {
                            addPlaylist(playlistId: playlist.id)
                        } label: {
                            Text(playlist.name)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .appList()
            .navigationTitle("Add Playlist")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                reload()
            }
        }
        .appScreen()
    }

    private func reload() {
        guard let appDatabase else { return }
        viewModel.reload(appDatabase: appDatabase, excluding: playlistId)
    }

    private func addPlaylist(playlistId sourceId: Int64) {
        guard let appDatabase else { return }
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            do {
                let trackIds = try appDatabase.repositories.playlists.fetchTrackIds(playlistId: sourceId)
                try appDatabase.repositories.playlists.addTracks(
                    playlistId: playlistId,
                    trackIds: trackIds,
                    position: nil,
                    addedAt: now
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Failed to add playlist."
                }
            }
        }
    }
}

private struct PlaylistSourceItem: Identifiable {
    let id: Int64
    let name: String
}

@MainActor
private final class PlaylistSourcePickerViewModel: ObservableObject {
    @Published var playlists: [PlaylistSourceItem] = []

    func reload(appDatabase: AppDatabase, excluding playlistId: Int64) {
        Task {
            await loadData(appDatabase: appDatabase, excluding: playlistId)
        }
    }

    private func loadData(appDatabase: AppDatabase, excluding playlistId: Int64) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> [PlaylistSourceItem] in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, name
                FROM playlists
                WHERE id <> ?
                ORDER BY name COLLATE NOCASE
                """,
                arguments: [playlistId]
            )
            return rows.compactMap { row -> PlaylistSourceItem? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Untitled Playlist"
                return PlaylistSourceItem(id: id, name: name)
            }
        }) ?? []

        playlists = snapshot
    }
}

#Preview {
    TrackPickerView(playlistId: 1)
}
