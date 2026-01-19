# Development Log

## 2026-01-19
- Created project folder structure (App/Data/Domain/Features/Services/Resources).
- Added GRDB integration and DB bootstrap (DatabasePool + WAL).
- Implemented schema + migrations (tracks, artists, albums, playlists, queue, history, recents, imports, lyrics, FTS).
- Added domain types: TrackSource, TrackRef, ImportMode, ImportState, RecentItemType.
- Added GRDB record models for core tables.
- Added repository layer: Track, History, Playlist, Queue, Recent, Import, ListeningStats.
- Added TrackSearchRepository with FTS5 query support.
- Added TrackIndexing helper for FTS updates.
- Added MetadataOverrideRepository and LyricsRepository to reindex on changes.
- Added AppRepositories container and injected into AppDatabase.
- Added tracks.title field and migration guard.
- Resolved GRDB package linking issue by removing GRDB-dynamic.
- Builds succeed via xcodebuild (generic iOS).
- Added minimal SwiftUI tab shell (Home/Library/Search + Settings sheet) for pilot UI.
- Updated Home/Library/Search view models to use async DatabasePool reads on main actor.
- Added record CodingKeys for snake_case column mapping.
- Added local import scaffolding (metadata reader + local importer) and import record fields.
- Added Library import UI (file picker + import mode controls) wired to LocalImportService.
- Added startup auto-scan for app import folders (Documents/Import + LibraryFiles).
- Enabled Files app access via Info.plist (file sharing + open in place).
- Added playback foundation (PlaybackController, queue handling, AVPlayer + remote commands, Now Playing updates).
- Added playback position persistence (table + repository + resume/save logic).
- Added queue persistence (restore on launch, store on queue updates).
- Added history trimming to 50 entries and recent items combined trimming support.
- Added minimal playback UI in Library (Now Playing controls + track list playback).
- Added security-scoped access handling for local file playback.
- Added playback state persistence (last track pointer + queue index restore).
- Added queue list UI with remove/clear actions in Library.
- Fixed Home display to show names instead of IDs/URIs; queue clear now persists synchronously.

## 2026-01-20
- Updated queue rules in spec (overwrite on new list playback, persisted queue, large-queue perf note).
- Increased history retention trim to 100 entries.
- Implemented queue add (play next / add to end) and reorder in pilot UI.
- Added missing-file handling: auto-skip on playback and store missing flag for local tracks.
- Implemented history playback (replace current item, keep queue after current).
- Improved playback recovery (play when current item is nil) and resolved bookmarks for referenced files.
- Made queue UI reactive to playback controller updates.
- Added missing-file management UI (relink/delete) in Library.
- Optimized queue persistence with incremental updates and background actor writes.
- Added local import dedup via partial content hash (skip duplicates, relink missing).
- Added import error surfacing in Library UI for debugging.
- Added import summary counts (imported/relinked/skipped/failed) to surface duplicate skips.
- Added Now Playing pilot screen with seek, playback controls, volume, and queue list.
- Switched Now Playing volume to system volume slider and separated controls from List to avoid tap conflicts.
- Now Playing uses a single scroll view; queue actions moved to context menu to avoid nested scroll regions.
- Refactored artwork upsert helpers to avoid actor-isolation warnings; rescan now backfills artwork for existing tracks missing artwork metadata.
- Expanded artwork backfill detection to cover missing artwork rows/files and rescan those tracks.
- Allowed artwork backfill to replace missing artwork files even when artwork IDs already exist.
- Added missing artwork repair pass on rescan (uses file URI or bookmarks when available).
- Missing-file relink now triggers artwork repair for that track.
- Fixed artwork backfill to avoid non-Sendable captures in DB writes.
- Relaxed artwork repair URL resolution to allow bookmark access before file-existence checks.
- Reverted to minimal bookmarks on iOS; expanded metadata reads to include full asset metadata for artwork recovery.
- Rescan now supports a forced artwork rebuild pass to re-extract embedded art for all tracks.
- Artwork upsert now updates stale file URIs when matching hashes are found.
- Audio metadata reader now merges format-specific metadata to improve artwork extraction on rescan.

## 2026-01-21
- Added playlist picker sheet to add a track to an existing playlist.
- Added album and artist browse lists with detail track lists for playback/queue actions.

## 2026-01-22
- Added recursive folder import support (skip hidden files) and Import Folder action.
- Added track/disc number metadata storage and album release year propagation.
- Added album/artist/playlist favorites with favorites-first sorting option.
- Moved Tracks/Playlists into Browse and exposed Favorites as a pseudo-playlist.
- Added playlist tools: last played tracking, bulk add (tracks/album/playlist), and playlist track sorting/reorder.
- Added album artist browse list + detail view (albums grouped by album artist).
- Added playlist rename and delete actions in playlist list.
- Implemented local search categories (artists/albums/tracks/playlists/lyrics) with category result screens.
- Expanded Settings: import mode controls, rescan, storage sizes, orphan cleanup, diagnostics counts.
- Added artwork extraction from metadata, storage with hash de-dup, and Now Playing artwork display.

## 2026-01-23
- Prefer resolved bookmark URLs when repairing artwork to restore reference-mode artwork on rescan.
- Refresh queue artwork from the database after rescan so queue display updates.
- Added auto artwork repair on startup when missing artwork is detected; status surfaces in Settings.
- Added auto artwork repair throttling (cooldown + per-run cap) and missing-reason tracking for missing files.
- Added embedded lyrics import and indexing; tightened duplicate detection with size/duration guard.
- Added Now Playing lyrics display for embedded lyrics.
- Added metadata edit sheet for app-copied tracks using metadata overrides; UI and playback display now honor overrides.
- Added metadata edit entry points in album and artist track lists.
- Added track deletion (DB-only for reference; file+DB for copied) and removal from in-memory queue.

## 2026-01-24
- Added import failure tracking (error message stored on failed import records).
- Added Settings action to retry failed imports and diagnostics count for failures.
- Store a bookmark for failed imports (all modes) so retry can reopen Files URLs.
- Added Settings list for failed imports with a clear action.
- Added Apple Music authorization scaffold and external search status UI (search still stubbed).
- Added Apple Music catalog search results (artists/albums/tracks/playlists) in external search scope.
- Improved playback stability: audio session interruption/route change handling, player status observation, buffering state updates.
- Avoided queue fetch blocking and SQLite variable limits via async + chunked queue item lookups.
- Moved playback position saves off the main actor via a dedicated writer actor.
- Updated previous-skip threshold to 4 seconds (<=4s goes to previous track).
- Mark local tracks as missing on playback failure when the file is unavailable.
- Added playback stall handling and media services reset recovery.
- Added Settings database repair to remove orphaned records.
- Queue restore now prunes missing entries and refreshes playback state if needed.
- Added missing-reason breakdown to Settings diagnostics.
- Added indexes to speed up library sorting and list loading.
- Expanded Settings diagnostics with queue/history/playback counts.
- Added import/rescan progress reporting via a shared progress center (shown in Library).
- Progress updates now dispatched on main actor to ensure UI visibility.
- Progress center is now observed via EnvironmentObject to render UI updates.
- Added copy-mode verification to compare source vs destination byte size and fail on mismatch.
- Default import mode is now Copy.
- Added UI foundation: theme tokens, glassy background, and base list/screen styling modifiers.
- Applied base screen/list styling to library, playlist, and search detail flows.
- Added UI building blocks: AppCard, AppSectionHeader, AppInlineInfo.
- Applied AppCard layouts to Home, Library (Import/Now Playing), and Now Playing header.
- Updated TabView to use search tab role and bottom accessory mini player.
- Mini player accessory now compacts when inline to avoid widening the tab group.
- Mini player accessory re-enabled after tab width verification.
- Mini player accessory now stays visible (disabled when idle) to keep tab width consistent.
- Removed custom glass-like backgrounds, borders, and rounded card styling to keep default UI components.
- Reverted Home/Library/Now Playing layouts back to standard List/Section (card usage removed).
- Locked row/tile component specifications for tracks, albums, and playlists in SPEC.
- Added alignment and collage fallback rules for favorites and playlist tiles.


## 2026-01-25
- Added shared UI components: AlbumTileView, PlaylistRowView, PlaylistTileView, PlaylistCollageView.
- Updated TrackRowView equalizer to remove material backdrop; ArtworkImageView now uses shared loader across screens.
- Swapped Now Playing artwork to the shared ArtworkImageView.
- Updated library lists to use new row/tile components (tracks, albums grid, album/artist detail tracks, album artist grid, playlists, favorites).
- Updated playlist detail to use track rows with swipe actions and context menus.
- Updated search category screens to use album/playlist grids and track/lyrics rows.
- Updated Home recents to use album/playlist tiles and track rows; recent queries now include artwork URIs and favorites.
- Added artwork URI joins + playlist collage mapping to list/search/home queries.
- Injected PlaybackController as an EnvironmentObject for now-playing row indicators.

## Notes
- Music capability not available under Personal Team; will enable after Developer Program.
- Info.plist usage descriptions pending.
- CLI xcodebuild can fail due to sandboxed cache permissions; verify builds in Xcode if needed.
