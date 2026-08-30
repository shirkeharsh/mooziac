# Storage

Every persistence mechanism in Mooziac.

## 1. SQLite database

| Attribute | Value |
| :--- | :--- |
| Location | `~/Library/Application Support/Mooziac/library.sqlite3` (+ `-wal`, `-shm`) |
| Owner | `LocalDatabaseManager` (raw SQLite3 C API) |
| Flags | `SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX` (serialized) |
| Journal | WAL; `synchronous = NORMAL`; `foreign_keys = ON`; `busy_timeout = 5000` |
| Version | `PRAGMA user_version` = **4** (constant `currentSchemaVersion = 3` is dead/misleading) |
| Tables | `tracks`, `playlists`, `playlist_items`, `listening_history`, `liked_songs` |
| Writers | LocalLibraryManager (tracks), PlaylistManager (playlists/items), HistoryManager (history), LikedSongsManager (liked_songs), DownloadManager (registration) |
| Readers | same + library views via managers |
| Threading | history ops on `dbQueue` (serial); other APIs rely on FULLMUTEX |
| Cleanup | `recoverCorruptDatabase` deletes + rebuilds on startup if open fails |
| Failure | prepare errors on some paths ignored; corrupt DB → rebuild (data loss) |

## 2. Offline audio files

| Attribute | Value |
| :--- | :--- |
| Location | `~/Library/Application Support/Mooziac/Offline/` and `~/Music/Mooziac/` (default; configurable via `YTM_downloadsFolder`) |
| Owner | `LocalLibraryManager` (scans) + `DownloadManager` (writes) |
| Formats | mp3, m4a, flac, wav, aac, ogg, opus |
| Download sandbox | `~/Music/Mooziac/.downloading/<jobId>/` during download, then finalized into place |
| Cleanup | `.downloading` dirs cleaned on startup (`cleanupStaleDownloads`) and on cancel |

## 3. UserDefaults (settings + session)

| Attribute | Value |
| :--- | :--- |
| Owner | all managers/views write directly |
| Keys | 38 (see `08_DATA/STATE_MANAGEMENT.md`) |
| Lifecycle | settings persist; session keys (`YTM_last*`) rewritten constantly; two keys deleted each launch (see risks) |

## 4. Caches (filesystem)

| Cache | Location | Owner |
| :--- | :--- | :--- |
| Lyrics | `~/Library/Caches/Mooziac/Lyrics/` | LyricsManager |
| Artwork thumbnails | `~/Library/Caches/Mooziac/Thumbnails/` | AppArtworkHelper |
| Notification art | `<tmp>/ytm_art_<UUID>.jpg` | TrackNotificationManager |

## 5. Memory state

- `NowPlayingManager.currentState` (PlaybackState) — canonical snapshot.
- `LocalLibraryManager.allTracks` — in-memory track list refreshed by scans.
- `AppArtworkHelper` memory cache — 500 items / 50 MB cap.
- `DownloadManager` queue/tasks, `PlaylistManager.activeContext` — in-memory.

## 6. Discord IPC (transient)

- UNIX socket `/tmp/discord-ipc-0…9` (not persistent storage).

## Storage matrix

| Storage | Location | Writer | Reader | Format | Lifecycle | Cleanup | Failure behavior |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| SQLite | App Support/Mooziac | managers | managers/views | SQLite3 | persistent | none | corrupt → delete+rebuild |
| Audio files | Music/Offline | DownloadManager | NativeAudioPlayer | media | persistent | user/manual | — |
| UserDefaults | standard | all | all | plist | persistent | legacy purge + init deletes | silent |
| Lyrics cache | Caches/Mooziac | LyricsManager | LyricsManager | text | persistent | none | swallowed |
| Thumbnails | Caches/Mooziac | AppArtworkHelper | views | JPEG | evicted by size/OS | OS-managed | nil fallback |
| Memory caches | RAM | managers | views | objects | app-lifetime | caps | — |