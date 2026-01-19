# Development Plan (v1)

This plan is the single source of truth for upcoming work. Update it as scope changes.

## Current Status (2026-01-24)
- Data foundation: GRDB DatabasePool + WAL, schema + migrations, repositories, FTS index.
- Pilot UI: SwiftUI shell with Home/Library/Search tabs + Settings sheet.
- Playback base: AVPlayer controller, queue persistence, playback position save/resume, current track pointer stored.
- Local import: reference/copy/copy-then-delete, recursive folder import, dedup (hash + size/duration), error tracking + retry.
- Artwork pipeline: extraction + storage, rescan + auto repair, queue artwork refresh.
- Lyrics: embedded import, indexed for search, Now Playing display.
- Metadata overrides: edit UI for app-copied tracks; overrides used in playback/search/lists.
- Library browse: albums/artists/tracks/playlists + album artist list; favorites as pseudo-playlist.
- Playlist management: bulk add, reorder, sorting, rename/delete, last-played tracking.
- Missing file handling: auto-skip for playback; missing flag + reason + relink/delete flow.
- Search: local categories + category result screens; Apple Music external search (catalog list results).
- Apple Music: authorization scaffolded; playback wiring pending.
- Settings maintenance: import mode, rescan, storage sizes, orphan cleanup, diagnostics, auto-repair status, retry failed imports.
- Playback stability: async queue item fetch, audio session interruption handling, buffering state updates.
- Playback persistence: async playback position writes.
- Playback stability: mark local tracks as missing when playback fails due to missing files.
- Playback stability: handle playback stalls and media services resets.
- Data integrity: add Settings database repair for orphaned records.
- Queue persistence: prune missing queue entries on restore and refresh playback state.
- Missing/permissions: add missing-reason breakdown to diagnostics.
- Performance: add indexes for library sorting and list queries.
- Diagnostics: surface queue/history/playback counts in Settings.
- Import/rescan: add progress reporting surfaced in Library.
- Not started: Apple Music integration, streaming, final UI polish.
- UI foundation: theme tokens, glass background, and base list/screen styling.
- UI foundation: shared components (card, section header, inline info) ready for reuse.
- UI polish: applied cards to Home, Library (Import/Now Playing), and Now Playing header.
- TabView spec locked: search tab role, bottom accessory mini player, no minimize behavior.

## Phase 1: Data + App Infrastructure (Done)
- Database schema, migrations, repositories, FTS indexing.
- Environment injection and basic UI navigation.

## Phase 2: Local Import + Library Ingestion (Done)
Goal: get files into the database with reliable metadata and storage policy.
- Import modes: reference, copy, copy-then-delete.
- Security-scoped bookmarks for external Files access.
- App folder auto-scan on launch (non-blocking; background task).
- Metadata extraction from local audio (title/artist/album/genre/year/track/disc).
- Import records to track source and status.
- Indexing into FTS on import/update.
- Folder import (recursive, skip hidden).
- Dedup via partial content hash.
- Import failure tracking + retry.
Deliverable: local files appear in library and search results.

## Phase 3: Playback Engine + Queue
Goal: play local tracks reliably with queue controls and persistence.
- Player service abstraction (local + future Apple Music).
- AVFoundation-backed local player with play/pause/seek/next/prev.
- Queue manager (enqueue, reorder, remove).
- Persist playback position per track.
- Background audio session + remote control integration.
- Update history, recents, listening stats.
Deliverable: playback with queue and lock screen controls.

## Phase 4: Library + Now Playing UI (Pilot) (Mostly done)
Goal: functional UI for core use cases (not final design).
- Library lists: tracks, albums, artists, playlists, favorites.
- Album/artist detail screens and track lists.
- Album artist list + detail.
- Now Playing screen (artwork, title, seek bar, queue).
- Queue screen and playlist editing.
Remaining:
- Artwork display in library lists (optional pilot polish).
Deliverable: usable local-player flow.

## Phase 5: Search UX + Categories (Mostly done)
Goal: spec-compliant search behavior.
- Single search bar with local/external toggle.
- Result ordering by category (artist, album, track, playlist, lyrics).
- Dedicated category result screens.
Remaining:
- External search integration (stub is in place).
Deliverable: local search complete, external stub ready.

## Phase 6: Apple Music + Music Library
Goal: streaming support via official APIs.
- MusicKit auth flow and library access.
- Apple Music catalog search and playback.
- Library sync for playlists and favorites (if allowed).
- Playback routing for streaming vs local.
Deliverable: Apple Music integration (Personal Team blocks capabilities until upgrade).

## Phase 7: Lyrics + Metadata Editing (Done)
Goal: lyrics display and local metadata overrides.
- Embedded lyrics parsing.
- Optional external provider (policy/license checked).
- Metadata edit UI for app-copied files only.
Deliverable: lyrics display + edit flow for local files.

## Phase 8: Settings + Maintenance (Done)
Goal: user control and reliability.
- Import mode settings and storage management.
- Cache management and orphan cleanup.
- Diagnostics view (db size, import errors).
Progress:
- Pilot settings implemented (import mode, rescan, storage sizes, orphan cleanup, diagnostics, retry failed imports).

## Phase 9: UI Polish (Liquid Glass)
Goal: iOS 26 design refinement.
- Replace pilot UI with final layouts and animations.
- Artwork-driven theming and transitions.

## Cross-cutting Tasks
- Add unit tests for repositories and indexing.
- Add integration tests for import/playback flows.
- Performance checks for large libraries.
- Accessibility pass.

## Known Gates / Risks
- Apple Music capabilities require Developer Program enrollment.
- External lyrics APIs require licensing and rate-limit handling.
- Security-scoped bookmarks and file access must be stable across launches.

## Next Milestone (Resume Work)
Phase 6: Apple Music integration (blocked until Developer Program).
Then Phase 9: UI polish (Liquid Glass) after core logic is complete.
