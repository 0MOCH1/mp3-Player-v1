# mp3 Player Spec (v1.0 summary)

## Scope
- iPhone only, iOS 26+.
- App Store distribution.
- UI follows Apple defaults; full UI polish later. Pilot UI acceptable.

## Sources
- Local: Files / app sandbox / Music library.
- Streaming: Apple Music required (MusicKit). Others only via official SDKs.
- Generic URL streaming supported (http/https). Offline for streaming is future-only if policy allows.
- DRM bypass not allowed; playback only via official APIs.

## Playback Features
- Play/pause, seek, next/prev.
- Shuffle, repeat.
- Queue management.
- Volume control.
- Favorites.
- Background playback, lock screen, headphone controls, landscape player.
- AirPlay/Bluetooth if possible. CarPlay not supported.
- Previous behavior: if playback position is above 4 seconds, seek to start; otherwise go to previous track.

## Library + Metadata
- Library fields: artist, album artist, album, genre, release year, track number, disc number, artwork, album artwork.
- Metadata edit: app-copied files only. Edits stored as DB override, not written to source file; lists/playback/search prefer overrides while album/artist grouping remains based on original tags.
- Track deletion: removes the library entry; for copy/copy-then-delete imports the app file is deleted, for reference imports only the DB entry is removed.

## Import
- Modes: reference / copy / copy_then_delete.
- Default mode: copy.
- User selects at first import; can change later.
- Delete original only with user permission.
- Auto-scan app folder on launch (non-blocking if needed).
- Folder import uses recursive scan; hidden files are skipped.
- Local dedup: compute content hash (partial hash) and avoid duplicate registration; guarded by file size + duration match when available.
- If a duplicate is found, skip new registration; if existing entry is missing, relink to the new file.
- For copy-then-delete, duplicates never trigger original deletion.
- Embedded artwork is extracted, stored in app storage, and referenced by hash.
- Failed imports are recorded with an error message and can be retried from Settings.
- Import and rescan progress is surfaced in the Library import section.

## Lyrics
- Primary: embedded tags (imported on local ingest and indexed for search).
- External API optional if licensing allows.

## Search
- Single search bar; toggle local vs external.
- Result order: artist -> album -> track -> playlist -> lyrics.
- Category-specific results screen accessible.
- External scope shows Apple Music authorization status and catalog search results (artists/albums/tracks/playlists; playback not wired yet).

## Home
- Recent items: albums + playlists.
- Recent plays: tracks.
- Top artists: last 30 days, top 10 by play count. If heavy, fallback to recent artists.

## Persistence
- History entries max 100.
- Recent items: albums + playlists total 50.
- Playback position saved.
- Queue persists across launches with last track pointer for resume.
- Playlists store last_played_at for sorting (only when playback starts from a playlist).

## Extensibility (fixed decisions)
- TrackRef = source + sourceTrackId.
- Metadata layering: source tags + overrides + display compose.
- Search indexes separated by source; merged for UI.
- Lyrics provider abstraction; embedded preferred.
- Download policy explicit (currently notAllowed).

## Queue Rules
- Selecting a track inside an album/playlist/track list queues the selected track and all following tracks in that list; starting playback from another list overwrites the existing queue.
- Queue supports: remove at any position, add "Play Next" or "Add to End" (default).
- Queue supports reordering.
- Duplicate tracks are allowed.
- When a track finishes, it is recorded in history.
- Playing a track from history replaces the currently playing track only; the remaining queue after the current track is unchanged.
- Queue is persisted across launches; no hard cap, but large queues should be handled with performance safeguards.

## Missing Files
- If the current/queued local file is missing or unreadable, auto-skip to the next playable item.
- Missing entries remain in the library with a missing flag and reason (not_found / permission / invalid_uri), with relink or delete options.

## Tech
- SwiftUI app.
- GRDB + SQLite + FTS5.
- AVFoundation for local playback.
- MusicKit/MediaPlayer for Apple Music/library.

## Tab Bar (Liquid Glass)
- TabView uses standard tabs so Liquid Glass applies automatically in iOS 26.
- Tabs: Home, Library, Search (Search uses `Tab(role: .search)`).
- Tab minimization: disabled for now (no `tabBarMinimizeBehavior`).
- Mini player: uses `tabViewBottomAccessory`; shown persistently and disabled when no active item to keep tab layout stable.
- Compatibility key `UIDesignRequiresCompatibility` is not used.

## UI Components (Rows/Tiles)
- Track row:
  - Leading: favorite icon shown only when favorited (no toggle on tap).
  - Artwork at left; in album detail lists, show track number instead of artwork (use "-" when missing).
  - Trailing: "..." button opens the same context menu as long-press.
  - Tap plays; long-press shows context menu.
  - Now playing indicator: 5-bar vertical visualizer overlay on artwork; when showing track number, replace number with the visualizer.
- Track row swipe actions:
  - Swipe right: add to end of queue (all screens).
  - Swipe left: remove from playlist when in playlist detail; otherwise delete from library.
- Album tile (2-column grid):
  - Square artwork as primary.
  - Below: album name + favorite icon (only if favorited) and album artist (fallback to track artist if album artist missing).
  - Tap opens; long-press shows context menu.
- Playlist row:
  - Taller track-row style; show favorite icon only when favorited.
  - No now-playing visual change.
- Playlist tile (2-column grid):
  - Square 2x2 collage of track artwork.
  - Below: playlist name + favorite icon (only if favorited).
  - Favorite icon reserves space even when not favorited to keep alignment.
  - Collage fallback: missing artwork uses a placeholder icon; fewer than 4 items show only available artwork.
  - Collage layout: 1 item fills the square; 2 items split evenly; 3 items use a 2-up top row + full-width bottom; 4 items use a 2x2 grid.

## Favorites + Sorting
- Favorites: tracks, albums, artists, playlists (Favorites is shown as a pseudo-playlist).
- Favorites-first option for album/artist/playlist lists.
- Sorting:
  - Playlists: title / created date / last played / updated date, asc/desc.
  - Albums: title / added date / artist / release year, asc/desc.
  - Tracks: title / added date / artist, asc/desc.
  - Playlist tracks: manual order (default, reorderable), title / artist / album / release year / added date, asc/desc.
- Album artist browse: list derived from album_artist_id, showing albums for the selected artist.

## Artwork (Pilot)
- Artwork is stored on disk in app storage and de-duplicated by content hash.
- Track artwork prefers embedded image; album artwork uses the album's stored artwork.

## Settings (Pilot)
- Import mode selection + delete-original toggle (copy-then-delete).
- Manual rescan of app folders.
- Auto artwork repair on launch (missing-only, throttled, per-run cap) with lightweight status in Settings.
- Storage: database size, library files size, import folder size.
- Orphaned library file cleanup.
- Diagnostics: counts for tracks/albums/artists/playlists/queue/history/playback positions/state/missing/import records.
- Failed import list with retry/clear actions.
- Database repair to remove orphaned records (queue/history/recents/lyrics/etc).
- Diagnostics include missing reason breakdown (not_found / permission / invalid_uri).
