import Combine
import GRDB
import SwiftUI

struct PlaylistPickerView: View {
    let trackIds: [Int64]
    let trackTitle: String?

    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PlaylistPickerViewModel()
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
                            addToPlaylist(playlist)
                        } label: {
                            Text(playlist.name)
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
            .navigationTitle("Add to Playlist")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadIfNeeded(appDatabase: appDatabase)
            }
        }
        .appScreen()
    }

    private func addToPlaylist(_ playlist: PlaylistPickerSummary) {
        guard let appDatabase else {
            statusMessage = "Database unavailable."
            return
        }
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            do {
                try appDatabase.repositories.playlists.addTracks(
                    playlistId: playlist.id,
                    trackIds: trackIds,
                    position: nil,
                    addedAt: now
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    let label = trackTitle ?? "tracks"
                    statusMessage = "Failed to add \(label)."
                }
            }
        }
    }
}

private struct PlaylistPickerSummary: Identifiable {
    let id: Int64
    let name: String
}

@MainActor
private final class PlaylistPickerViewModel: ObservableObject {
    @Published var playlists: [PlaylistPickerSummary] = []

    private var didLoad = false

    func loadIfNeeded(appDatabase: AppDatabase?) {
        guard !didLoad, let appDatabase else { return }
        didLoad = true
        Task {
            await loadData(appDatabase: appDatabase)
        }
    }

    private func loadData(appDatabase: AppDatabase) async {
        let snapshot = (try? await appDatabase.dbPool.read { db -> [PlaylistPickerSummary] in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, name
                FROM playlists
                ORDER BY updated_at DESC
                LIMIT 100
                """
            )
            return rows.compactMap { row -> PlaylistPickerSummary? in
                guard let id = row["id"] as Int64? else { return nil }
                let name = row["name"] as String? ?? "Untitled Playlist"
                return PlaylistPickerSummary(id: id, name: name)
            }
        }) ?? []

        playlists = snapshot
    }
}

#Preview {
    PlaylistPickerView(trackIds: [1], trackTitle: "Track")
}
