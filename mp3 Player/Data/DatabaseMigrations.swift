import GRDB

extension AppDatabase {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("create_v1") { db in
            try db.create(table: "artworks") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("file_uri", .text).notNull()
                t.column("width", .integer)
                t.column("height", .integer)
                t.column("hash", .text)
                t.column("created_at", .integer).notNull()
            }

            try db.create(table: "artists") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("sort_name", .text)
                t.column("is_favorite", .boolean).notNull().defaults(to: false)
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
            }

            try db.create(table: "albums") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("album_artist_id", .integer).references("artists", onDelete: .setNull)
                t.column("release_year", .integer)
                t.column("artwork_id", .integer).references("artworks", onDelete: .setNull)
                t.column("is_favorite", .boolean).notNull().defaults(to: false)
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
            }

            try db.create(table: "tracks") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("source", .text).notNull()
                t.column("source_track_id", .text).notNull()
                t.column("title", .text).notNull().defaults(to: "")
                t.column("duration", .double)
                t.column("file_uri", .text)
                t.column("content_hash", .text)
                t.column("file_size", .integer)
                t.column("track_number", .integer)
                t.column("disc_number", .integer)
                t.column("is_missing", .boolean).notNull().defaults(to: false)
                t.column("missing_reason", .text)
                t.column("is_favorite", .boolean).notNull().defaults(to: false)
                t.column("album_id", .integer).references("albums", onDelete: .setNull)
                t.column("artist_id", .integer).references("artists", onDelete: .setNull)
                t.column("album_artist_id", .integer).references("artists", onDelete: .setNull)
                t.column("genre", .text)
                t.column("release_year", .integer)
                t.column("artwork_id", .integer).references("artworks", onDelete: .setNull)
                t.column("album_artwork_id", .integer).references("artworks", onDelete: .setNull)
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
                t.uniqueKey(["source", "source_track_id"])
            }

            try db.create(table: "metadata_overrides") { t in
                t.column("track_id", .integer).primaryKey().references("tracks", onDelete: .cascade)
                t.column("title", .text)
                t.column("artist_name", .text)
                t.column("album_name", .text)
                t.column("genre", .text)
                t.column("release_year", .integer)
                t.column("artwork_id", .integer).references("artworks", onDelete: .setNull)
                t.column("album_artwork_id", .integer).references("artworks", onDelete: .setNull)
                t.column("updated_at", .integer).notNull()
            }

            try db.create(table: "playlists") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("is_favorite", .boolean).notNull().defaults(to: false)
                t.column("last_played_at", .integer)
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
            }

            try db.create(table: "playlist_tracks") { t in
                t.column("playlist_id", .integer).notNull().references("playlists", onDelete: .cascade)
                t.column("track_id", .integer).notNull().references("tracks", onDelete: .cascade)
                t.column("ord", .integer).notNull()
                t.column("added_at", .integer).notNull()
                t.primaryKey(["playlist_id", "ord"])
            }

            try db.create(table: "queue_items") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("source", .text).notNull()
                t.column("source_track_id", .text).notNull()
                t.column("ord", .integer).notNull()
                t.column("added_at", .integer).notNull()
            }

            try db.create(table: "history_entries") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("source", .text).notNull()
                t.column("source_track_id", .text).notNull()
                t.column("played_at", .integer).notNull()
                t.column("position", .double).notNull()
            }

            try db.create(table: "recent_items") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("entity_type", .text).notNull()
                t.column("entity_id", .integer).notNull()
                t.column("last_opened_at", .integer).notNull()
            }

            try db.create(table: "listening_stats") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("artist_id", .integer).notNull().references("artists", onDelete: .cascade)
                t.column("day", .integer).notNull()
                t.column("play_count", .integer).notNull()
                t.uniqueKey(["artist_id", "day"])
            }

            try db.create(table: "import_records") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("original_uri", .text)
                t.column("copied_uri", .text)
                t.column("import_mode", .text).notNull()
                t.column("state", .text).notNull()
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
            }

            try db.create(table: "lyrics") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("source", .text).notNull()
                t.column("source_track_id", .text).notNull()
                t.column("provider", .text).notNull()
                t.column("content", .text).notNull()
                t.column("created_at", .integer).notNull()
                t.uniqueKey(["source", "source_track_id", "provider"])
            }

            try db.create(index: "idx_tracks_source", on: "tracks", columns: ["source", "source_track_id"], unique: true)
            try db.create(index: "idx_playlist_tracks", on: "playlist_tracks", columns: ["playlist_id", "ord"])
            try db.create(index: "idx_history_played_at", on: "history_entries", columns: ["played_at"])
            try db.create(index: "idx_recent_items", on: "recent_items", columns: ["last_opened_at"])
            try db.create(index: "idx_listening_stats_day", on: "listening_stats", columns: ["day"])

            try db.create(virtualTable: "tracks_fts", using: FTS5()) { t in
                t.column("track_id").notIndexed()
                t.column("title")
                t.column("artist")
                t.column("album")
                t.column("genre")
                t.column("lyrics")
            }
        }

        migrator.registerMigration("add_track_title") { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(tracks)")
            let hasTitle = rows.contains { row in
                (row["name"] as String?) == "title"
            }
            if !hasTitle {
                try db.alter(table: "tracks") { t in
                    t.add(column: "title", .text).notNull().defaults(to: "")
                }
            }
        }

        migrator.registerMigration("add_import_record_fields") { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(import_records)")
            let names = Set(rows.compactMap { $0["name"] as String? })

            if !names.contains("track_id") {
                try db.alter(table: "import_records") { t in
                    t.add(column: "track_id", .integer)
                }
            }

            if !names.contains("bookmark_data") {
                try db.alter(table: "import_records") { t in
                    t.add(column: "bookmark_data", .blob)
                }
            }
        }

        migrator.registerMigration("add_playback_positions") { db in
            try db.create(table: "playback_positions") { t in
                t.column("source", .text).notNull()
                t.column("source_track_id", .text).notNull()
                t.column("position", .double).notNull()
                t.column("updated_at", .integer).notNull()
                t.primaryKey(["source", "source_track_id"])
            }
        }

        migrator.registerMigration("add_playback_state") { db in
            try db.create(table: "playback_state") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("source", .text).notNull()
                t.column("source_track_id", .text).notNull()
                t.column("queue_index", .integer).notNull()
                t.column("updated_at", .integer).notNull()
            }
        }

        migrator.registerMigration("add_track_missing_flag") { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(tracks)")
            let names = Set(rows.compactMap { $0["name"] as String? })
            if !names.contains("is_missing") {
                try db.alter(table: "tracks") { t in
                    t.add(column: "is_missing", .boolean).notNull().defaults(to: false)
                }
            }
        }

        migrator.registerMigration("add_track_missing_reason") { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(tracks)")
            let names = Set(rows.compactMap { $0["name"] as String? })
            if !names.contains("missing_reason") {
                try db.alter(table: "tracks") { t in
                    t.add(column: "missing_reason", .text)
                }
            }
        }

        migrator.registerMigration("add_track_content_hash") { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(tracks)")
            let names = Set(rows.compactMap { $0["name"] as String? })
            if !names.contains("content_hash") {
                try db.alter(table: "tracks") { t in
                    t.add(column: "content_hash", .text)
                }
            }
            if !names.contains("file_size") {
                try db.alter(table: "tracks") { t in
                    t.add(column: "file_size", .integer)
                }
            }
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_tracks_content_hash ON tracks(content_hash)")
        }

        migrator.registerMigration("add_track_favorite_flag") { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(tracks)")
            let names = Set(rows.compactMap { $0["name"] as String? })
            if !names.contains("is_favorite") {
                try db.alter(table: "tracks") { t in
                    t.add(column: "is_favorite", .boolean).notNull().defaults(to: false)
                }
            }
        }

        migrator.registerMigration("add_track_numbers") { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(tracks)")
            let names = Set(rows.compactMap { $0["name"] as String? })
            if !names.contains("track_number") {
                try db.alter(table: "tracks") { t in
                    t.add(column: "track_number", .integer)
                }
            }
            if !names.contains("disc_number") {
                try db.alter(table: "tracks") { t in
                    t.add(column: "disc_number", .integer)
                }
            }
        }

        migrator.registerMigration("add_library_favorites") { db in
            let artistRows = try Row.fetchAll(db, sql: "PRAGMA table_info(artists)")
            let artistNames = Set(artistRows.compactMap { $0["name"] as String? })
            if !artistNames.contains("is_favorite") {
                try db.alter(table: "artists") { t in
                    t.add(column: "is_favorite", .boolean).notNull().defaults(to: false)
                }
            }

            let albumRows = try Row.fetchAll(db, sql: "PRAGMA table_info(albums)")
            let albumNames = Set(albumRows.compactMap { $0["name"] as String? })
            if !albumNames.contains("is_favorite") {
                try db.alter(table: "albums") { t in
                    t.add(column: "is_favorite", .boolean).notNull().defaults(to: false)
                }
            }

            let playlistRows = try Row.fetchAll(db, sql: "PRAGMA table_info(playlists)")
            let playlistNames = Set(playlistRows.compactMap { $0["name"] as String? })
            if !playlistNames.contains("is_favorite") {
                try db.alter(table: "playlists") { t in
                    t.add(column: "is_favorite", .boolean).notNull().defaults(to: false)
                }
            }
        }

        migrator.registerMigration("add_playlist_last_played_at") { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(playlists)")
            let names = Set(rows.compactMap { $0["name"] as String? })
            if !names.contains("last_played_at") {
                try db.alter(table: "playlists") { t in
                    t.add(column: "last_played_at", .integer)
                }
            }
        }

        migrator.registerMigration("add_import_record_error_message") { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(import_records)")
            let names = Set(rows.compactMap { $0["name"] as String? })
            if !names.contains("error_message") {
                try db.alter(table: "import_records") { t in
                    t.add(column: "error_message", .text)
                }
            }
        }

        migrator.registerMigration("add_library_sort_indexes") { db in
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_artists_name_nocase ON artists(name COLLATE NOCASE)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_albums_name_nocase ON albums(name COLLATE NOCASE)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_albums_created_at ON albums(created_at)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_albums_release_year ON albums(release_year)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_albums_album_artist_id ON albums(album_artist_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_tracks_title_nocase ON tracks(title COLLATE NOCASE)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_tracks_created_at ON tracks(created_at)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_tracks_artist_id ON tracks(artist_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_tracks_album_id ON tracks(album_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_playlists_name_nocase ON playlists(name COLLATE NOCASE)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_playlists_created_at ON playlists(created_at)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_playlists_updated_at ON playlists(updated_at)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_playlists_last_played_at ON playlists(last_played_at)")
        }

        return migrator
    }
}
