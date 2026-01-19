import GRDB
import SwiftUI

struct TrackMetadataEditorView: View {
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.dismiss) private var dismiss

    let trackId: Int64
    let onSave: () -> Void

    @State private var title = ""
    @State private var artist = ""
    @State private var album = ""
    @State private var genre = ""
    @State private var releaseYear = ""
    @State private var baseTitle = ""
    @State private var baseArtist = ""
    @State private var baseAlbum = ""
    @State private var baseGenre = ""
    @State private var baseReleaseYear: Int?
    @State private var errorMessage: String?
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Metadata") {
                    TextField("Title", text: $title)
                    TextField("Artist", text: $artist)
                    TextField("Album", text: $album)
                    TextField("Genre", text: $genre)
                    TextField("Release Year", text: $releaseYear)
                        .keyboardType(.numberPad)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Section {
                    Button("Reset to Original") {
                        resetToBase()
                    }
                }
            }
            .appList()
            .navigationTitle("Edit Metadata")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .task {
                guard !didLoad else { return }
                didLoad = true
                await loadData()
            }
        }
        .appScreen()
    }

    private func loadData() async {
        guard let appDatabase else {
            errorMessage = "Database unavailable."
            return
        }

        let row = try? appDatabase.dbPool.read { db -> Row? in
            try Row.fetchOne(
                db,
                sql: """
                SELECT
                    t.title AS base_title,
                    a.name AS base_artist,
                    al.name AS base_album,
                    t.genre AS base_genre,
                    t.release_year AS base_release_year,
                    mo.title AS override_title,
                    mo.artist_name AS override_artist,
                    mo.album_name AS override_album,
                    mo.genre AS override_genre,
                    mo.release_year AS override_release_year
                FROM tracks t
                LEFT JOIN artists a ON a.id = t.artist_id
                LEFT JOIN albums al ON al.id = t.album_id
                LEFT JOIN metadata_overrides mo ON mo.track_id = t.id
                WHERE t.id = ?
                """,
                arguments: [trackId]
            )
        }

        guard let row else {
            errorMessage = "Track not found."
            return
        }

        baseTitle = row["base_title"] as String? ?? "Unknown Title"
        baseArtist = row["base_artist"] as String? ?? ""
        baseAlbum = row["base_album"] as String? ?? ""
        baseGenre = row["base_genre"] as String? ?? ""
        baseReleaseYear = row["base_release_year"] as Int?

        let overrideTitle = row["override_title"] as String?
        let overrideArtist = row["override_artist"] as String?
        let overrideAlbum = row["override_album"] as String?
        let overrideGenre = row["override_genre"] as String?
        let overrideReleaseYear = row["override_release_year"] as Int?

        title = overrideTitle ?? baseTitle
        artist = overrideArtist ?? baseArtist
        album = overrideAlbum ?? baseAlbum
        genre = overrideGenre ?? baseGenre
        if let overrideReleaseYear {
            releaseYear = String(overrideReleaseYear)
        } else if let baseReleaseYear {
            releaseYear = String(baseReleaseYear)
        } else {
            releaseYear = ""
        }
    }

    private func resetToBase() {
        title = baseTitle
        artist = baseArtist
        album = baseAlbum
        genre = baseGenre
        releaseYear = baseReleaseYear.map { String($0) } ?? ""
    }

    private func saveChanges() {
        guard let appDatabase else {
            errorMessage = "Database unavailable."
            return
        }

        let titleOverride = normalizedOverride(value: title, base: baseTitle)
        let artistOverride = normalizedOverride(value: artist, base: baseArtist)
        let albumOverride = normalizedOverride(value: album, base: baseAlbum)
        let genreOverride = normalizedOverride(value: genre, base: baseGenre)

        let trimmedYear = releaseYear.trimmingCharacters(in: .whitespacesAndNewlines)
        let releaseOverride: Int?
        if trimmedYear.isEmpty {
            releaseOverride = nil
        } else if let parsed = Int(trimmedYear) {
            if let baseReleaseYear, parsed == baseReleaseYear {
                releaseOverride = nil
            } else {
                releaseOverride = parsed
            }
        } else {
            errorMessage = "Release year must be a number."
            return
        }

        let hasOverrides = titleOverride != nil
            || artistOverride != nil
            || albumOverride != nil
            || genreOverride != nil
            || releaseOverride != nil

        let now = Int64(Date().timeIntervalSince1970)
        Task {
            if hasOverrides {
                let record = MetadataOverrideRecord(
                    trackId: trackId,
                    title: titleOverride,
                    artistName: artistOverride,
                    albumName: albumOverride,
                    genre: genreOverride,
                    releaseYear: releaseOverride,
                    artworkId: nil,
                    albumArtworkId: nil,
                    updatedAt: now
                )
                try? appDatabase.repositories.metadataOverrides.upsert(record)
            } else {
                try? appDatabase.repositories.metadataOverrides.delete(trackId: trackId)
            }
            await MainActor.run {
                onSave()
                dismiss()
            }
        }
    }

    private func normalizedOverride(value: String, base: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed == base {
            return nil
        }
        return trimmed
    }
}
