# Mooziac — Data Managers Technical Blueprint

Reverse-engineering archive. READ-ONLY analysis; no source was modified.

## Scope & Method

Four source files read line-by-line and documented:

| File | Lines | Role |
| :--- | :--- | :--- |
| `Sources/Mooziac/Managers/LocalDatabaseManager.swift` | 1243 | SQLite persistence singleton |
| `Sources/Mooziac/Managers/LocalLibraryManager.swift` | 490 | Filesystem library scan + metadata |
| `Sources/Mooziac/Managers/PlaylistManager.swift` | 865 | Playlist business logic + playback orchestration |
| `Sources/Mooziac/Managers/DownloadManager.swift` | 1013 | yt-dlp download pipeline |

External symbols referenced by these files were located and confirmed in the repo
(`LocalTrack`, `LikedSongRecord`, `LyricsManager`, `NetworkMonitor`, `NativeAudioPlayer`,
`NowPlayingManager`, `AppArtworkHelper`, `StatusItemManager`, `YTMWebViewContainer`,
`PlaybackState`, `QueueItemInfo`, `UpNextSnapshot`, `PlaybackEngineMode`, `RepeatMode`).
Anything not verifiable from source is explicitly flagged
`INFERRED FROM SOURCE` or `UNKNOWN — REQUIRES RUNTIME VERIFICATION`.

Legend: `LDM` = LocalDatabaseManager, `LLM` = LocalLibraryManager, `PM` = PlaylistManager, `DM` = DownloadManager.

---

## File 1 — `Sources/Mooziac/Managers/LocalDatabaseManager.swift`

### FILE ENTRY

- **File**: `Sources/Mooziac/Managers/LocalDatabaseManager.swift` (1243 lines)
- **Purpose**: Single-threaded-access SQLite persistence layer. Owns the on-disk
  database (`library.sqlite3`), schema migrations, and every table: tracks, playlists,
  playlist_items, listening_history, liked_songs.
- **Subsystem**: `Managers/` — persistence / local data.
- **What depends on it** (verified consumers):
  - `LocalLibraryManager` (fetchAllRecords, upsertTracks, deleteTracks, isLiked,
    setLiked, setYTVideoID, migrateLikedKeysFromUserDefaultsIfNeeded)
  - `PlaylistManager` (all playlist CRUD + item APIs)
  - `HistoryManager` (history APIs)
  - `LikedSongsManager` (liked-song APIs, fetchUnsyncedLikedSongs, setLikedSongSynced)
  - Views: `Views/Libraries/PlaylistLibraryView.swift`,
    `Views/Player/DynamicIslandPlayerView/SettingsPanel.swift`
- **What it depends on**: `AppKit` (import only, for NSImage via `LocalTrack`),
  `Foundation`, system `SQLite3` via `import SQLite3` (raw C API). No third-party deps.
- **Important imports**: `import AppKit`, `import Foundation`, `import SQLite3`.
- **Classes defined**: `LocalDatabaseManager` (public final, singleton). Plus 4 top-level
  value types: `CachedTrackRecord`, `PlaylistRecord`, `PlaylistItemRecord`, `HistoryRecord`.
- **Constants**:
  - `currentSchemaVersion: Int32 = 3` (line 188) — **DEAD CODE** (never read; migration
    code actually advances user_version to 4; see RISKS).
  - `SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)` — local
    constant re-derived in ~every function.
  - History prune cap literal `1000` (line 1134); `fetchHistory` default `limit: 200`.
- **Properties/state**:
  - `public static let shared` (line 184)
  - `private var db: OpaquePointer?` (line 186)
  - `private let dbQueue = DispatchQueue(label: "com.mooziac.localdatabase", qos: .userInitiated)` (line 187)
- **Events**: none posted by this file.
- **Side effects**: creates `~/Library/Application Support/Mooziac/library.sqlite3`
  (and directory), WAL/SHM files, destroys+rebuilds them on corruption recovery.
  On rebuild it prints `[LocalDatabaseManager] Rebuilding database from scratch...`.
- **External APIs / system frameworks**: raw SQLite3 C API
  (`sqlite3_open_v2`, `sqlite3_prepare_v2`, `sqlite3_step`, `sqlite3_column_*`,
  `sqlite3_bind_*`, `sqlite3_exec`, `sqlite3_close`, `sqlite3_finalize`,
  `sqlite3_free`, `sqlite3_reset`, `sqlite3_clear_bindings`), `FileManager`,
  `UserDefaults`.
- **Files it communicates with**: `~/Library/Application Support/Mooziac/library.sqlite3`
  (+ `library.sqlite3-wal`, `library.sqlite3-shm`). Communicates with
  `LocalLibraryManager`, `PlaylistManager`, `HistoryManager`, `LikedSongsManager`.

---

### FULL DATABASE SCHEMA (verbatim SQL)

Database file: `~/Library/Application Support/Mooziac/library.sqlite3`
(`databaseFileURL`, lines 190-197). Connection flags:
`SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX` (serialized mode).
Journal mode **WAL**; `synchronous = NORMAL`; `foreign_keys = ON`;
`busy_timeout = 5000`. Version tracked via `PRAGMA user_version`.

#### Table `tracks` (v1, lines 263-276)
Columns: `id TEXT PRIMARY KEY`, `file_path TEXT UNIQUE NOT NULL`,
`title TEXT NOT NULL`, `artist TEXT NOT NULL`, `album TEXT NOT NULL`,
`duration REAL NOT NULL`, `date_added REAL NOT NULL`, `date_modified REAL NOT NULL`,
`file_size INTEGER NOT NULL`, `is_liked INTEGER NOT NULL DEFAULT 0`,
`lrc_path TEXT`, `yt_video_id TEXT`.
Indexes: `idx_tracks_file_path` (file_path), `idx_tracks_date_added` (date_added),
`idx_tracks_yt_video_id` (yt_video_id).

#### Table `playlists` (v2, lines 327-333)
Columns: `id TEXT PRIMARY KEY`, `name TEXT NOT NULL`, `created_at REAL NOT NULL`,
`updated_at REAL NOT NULL`.

#### Table `playlist_items` (v2, lines 334-348)
Columns: `id TEXT PRIMARY KEY`, `playlist_id TEXT NOT NULL`,
`sort_order INTEGER NOT NULL`, `ref_type TEXT NOT NULL`, `ref_id TEXT NOT NULL`,
`yt_video_id TEXT`, `title TEXT NOT NULL`, `artist TEXT NOT NULL DEFAULT ''`,
`artwork_url TEXT NOT NULL DEFAULT ''`, `duration TEXT NOT NULL DEFAULT ''`,
`is_liked INTEGER NOT NULL DEFAULT 0`, `date_added REAL NOT NULL`,
`FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE`.
Indexes: `idx_playlist_items_playlist` (playlist_id, sort_order),
`idx_playlist_items_yt_video` (yt_video_id).

#### Table `listening_history` (v3, lines 359-371)
Columns: `id TEXT PRIMARY KEY`, `title TEXT NOT NULL`,
`artist TEXT NOT NULL DEFAULT ''`, `album TEXT NOT NULL DEFAULT ''`,
`artwork_url TEXT NOT NULL DEFAULT ''`, `yt_video_id TEXT`, `file_path TEXT`,
`played_at REAL NOT NULL`, `duration REAL NOT NULL DEFAULT 0.0`,
`source_type TEXT NOT NULL DEFAULT 'online'`.
Indexes: `idx_history_played_at` (played_at DESC), `idx_history_video_id`
(yt_video_id), `idx_history_file_path` (file_path).

#### Table `liked_songs` (v4, lines 383-394)
Columns: `video_id TEXT PRIMARY KEY`, `title TEXT NOT NULL`,
`artist TEXT NOT NULL DEFAULT ''`, `album TEXT NOT NULL DEFAULT ''`,
`artwork_url TEXT NOT NULL DEFAULT ''`, `duration REAL NOT NULL DEFAULT 0.0`,
`date_liked REAL NOT NULL`, `synced INTEGER NOT NULL DEFAULT 0`,
`source_type TEXT NOT NULL DEFAULT 'ytm'`.
Index: `idx_liked_songs_date` (date_liked DESC).

#### Migration gating
`applySchemaIfNeeded()` reads `PRAGMA user_version`; if `< 1` runs v1 DDL +
`setUserVersion(1)`; if `< 2` runs `migrateToV2()` (adds `yt_video_id` to tracks if
missing via `columnExists`/`ALTER TABLE`, plus playlists/playlist_items);
if `< 3` runs `migrateToV3()` (listening_history); if `< 4` runs `migrateToV4()`
(liked_songs). Each migration sets `user_version` on success and prints a log line.
Note: v1 DDL already includes `yt_video_id`, so `migrateToV2`'s ALTER is a no-op for
fresh installs (comment at line 320 acknowledges this).

#### All SQL strings (verbatim, with location)
PRAGMAs:
- `"PRAGMA journal_mode = WAL;"` (223, 251)
- `"PRAGMA synchronous = NORMAL;"` (224, 252)
- `"PRAGMA foreign_keys = ON;"` (225, 253)
- `"PRAGMA busy_timeout = 5000;"` (226, 254)
- `"PRAGMA user_version;"` (406)
- `"PRAGMA user_version = \(version);"` (416)
- `"PRAGMA table_info(\(table));"` (301)

DDL: as quoted in schema section above (263-276, 322, 324, 327-351, 359-375, 383-395).

DML/selects:
- `"SELECT id, file_path, title, artist, album, duration, date_added, date_modified, file_size, is_liked, lrc_path, yt_video_id FROM tracks;"` (439)
- upsert (489-504) — see below
- `"DELETE FROM tracks WHERE file_path = ?;"` (551)
- `"DELETE FROM playlist_items WHERE ref_type = 'local' AND ref_id = ?;"` (552)
- `"UPDATE tracks SET is_liked = ? WHERE file_path = ? OR id = ?;"` (591)
- `"SELECT is_liked FROM tracks WHERE file_path = ? OR id = ? LIMIT 1;"` (605)
- liked_songs upsert (638-648) — see below
- `"DELETE FROM liked_songs WHERE video_id = ?;"` (668)
- `"SELECT video_id FROM liked_songs WHERE video_id = ? LIMIT 1;"` (680)
- `"UPDATE liked_songs SET synced = 1 WHERE video_id = ?;"` (696)
- `"SELECT video_id, title, artist, album, artwork_url, duration, date_liked, synced, source_type FROM liked_songs ORDER BY date_liked DESC;"` (709)
- `"SELECT video_id, title, artist, album, artwork_url, duration, date_liked, synced, source_type FROM liked_songs WHERE synced = 0 ORDER BY date_liked DESC;"` (742)
- `"SELECT COUNT(*) FROM liked_songs;"` (774)
- `"UPDATE tracks SET yt_video_id = ? WHERE file_path = ?;"` (789)
- `"SELECT file_path FROM tracks WHERE yt_video_id = ?;"` (807)
- playlists+count (826-832):
  ```
  SELECT p.id, p.name, p.created_at, p.updated_at, COUNT(pi.id) AS item_count
  FROM playlists p
  LEFT JOIN playlist_items pi ON pi.playlist_id = p.id
  GROUP BY p.id
  ORDER BY p.updated_at DESC, p.created_at DESC;
  ```
- `"INSERT INTO playlists (id, name, created_at, updated_at) VALUES (?, ?, ?, ?);"` (853)
- `"UPDATE playlists SET name = ?, updated_at = ? WHERE id = ?;"` (870)
- `"DELETE FROM playlists WHERE id = ?;"` (884)
- `"UPDATE playlists SET updated_at = ? WHERE id = ?;"` (896)
- fetchPlaylistItems (911-916):
  ```
  SELECT id, playlist_id, sort_order, ref_type, ref_id, yt_video_id, title, artist, artwork_url, duration, is_liked, date_added
  FROM playlist_items
  WHERE playlist_id = ?
  ORDER BY sort_order ASC;
  ```
- `"DELETE FROM playlist_items WHERE playlist_id = ?;"` (952)
- insert playlist_items (953-956): 12 placeholders, columns
  `(id, playlist_id, sort_order, ref_type, ref_id, yt_video_id, title, artist, artwork_url, duration, is_liked, date_added)`
- `"DELETE FROM playlist_items WHERE id = ?;"` (1032)
- `"UPDATE playlist_items SET sort_order = ? WHERE id = ? AND playlist_id = ?;"` (1045)
- `"DELETE FROM listening_history WHERE yt_video_id = ?;"` (1072)
- `"DELETE FROM listening_history WHERE file_path = ?;"` (1083)
- `"DELETE FROM listening_history WHERE LOWER(TRIM(title)) = LOWER(TRIM(?)) AND LOWER(TRIM(artist)) = LOWER(TRIM(?));"` (1093)
- insert listening_history (1104-1107): 10 placeholders, columns
  `(id, title, artist, album, artwork_url, yt_video_id, file_path, played_at, duration, source_type)`
- prune: `"DELETE FROM listening_history WHERE id NOT IN (SELECT id FROM listening_history ORDER BY played_at DESC LIMIT 1000);"` (1134)
- fetchHistory (1142-1158): dedupe by max played_at grouped by
  CASE (yt_video_id → file_path → LOWER(TRIM(title)) || '|||' || LOWER(TRIM(artist))),
  `ORDER BY played_at DESC LIMIT ? OFFSET ?;`
- history count (1198-1204): `SELECT COUNT(DISTINCT CASE ... END) FROM listening_history;`
- `"DELETE FROM listening_history WHERE id = ?;"` (1221)
- `"DELETE FROM listening_history;"` (1239)
- transaction control: `"BEGIN TRANSACTION;"` (511, 563, 960, 1047), `"COMMIT;"` (543, 581, 995, 1060)

#### Upsert SQL (verbatim, 489-504)
```
INSERT INTO tracks (id, file_path, title, artist, album, duration, date_added, date_modified, file_size, is_liked, lrc_path, yt_video_id)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(file_path) DO UPDATE SET
    id = excluded.id,
    title = excluded.title,
    artist = excluded.artist,
    album = excluded.album,
    duration = excluded.duration,
    date_added = excluded.date_added,
    date_modified = excluded.date_modified,
    file_size = excluded.file_size,
    is_liked = excluded.is_liked,
    lrc_path = excluded.lrc_path,
    yt_video_id = COALESCE(excluded.yt_video_id, tracks.yt_video_id);
```

#### liked_songs upsert SQL (verbatim, 638-648)
```
INSERT INTO liked_songs (video_id, title, artist, album, artwork_url, duration, date_liked, synced, source_type)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(video_id) DO UPDATE SET
    title = excluded.title,
    artist = excluded.artist,
    album = excluded.album,
    artwork_url = excluded.artwork_url,
    duration = excluded.duration,
    synced = excluded.synced;
```

---

### CLASS ENTRY — `LocalDatabaseManager` (public final)

- **Purpose**: central SQLite access point for all persisted local data.
- **Responsibilities**: open/migrate/rebuild DB; CRUD tracks, playlists,
  playlist_items, listening_history, liked_songs; like-state; yt_video_id mapping;
  UserDefaults liked-key migration.
- **init**: `private init()` (199) calls `openAndInitializeDatabase()`. Singleton via
  `public static let shared`.
- **deinit** (203-207): `sqlite3_close(db)` if non-nil. Practically never runs (singleton).
- **Properties**: `db: OpaquePointer?` (private, mutable), `dbQueue` (private, serial,
  userInitiated), `currentSchemaVersion` (private, unused — dead), `databaseFileURL`
  (public computed).
- **Public API**: `shared`, `databaseFileURL`, `recoverCorruptDatabase`,
  `fetchAllRecords`, `upsertTracks`, `deleteTracks`, `setLiked`, `isLiked`,
  `migrateLikedKeysFromUserDefaultsIfNeeded`, `addLikedSong`, `removeLikedSong`,
  `isLikedSong`, `setLikedSongSynced`, `fetchLikedSongs`, `fetchUnsyncedLikedSongs`,
  `countLikedSongs`, `setYTVideoID`, `filePaths(byVideoID:)`,
  `fetchPlaylists`, `createPlaylist`, `renamePlaylist`, `deletePlaylist`,
  `touchPlaylist`, `fetchPlaylistItems`, `replacePlaylistItems`,
  `appendPlaylistItem`, `removePlaylistItem`, `reorderPlaylistItems`,
  `recordHistoryItem`, `fetchHistory`, `fetchHistoryCount`, `deleteHistoryItem`,
  `clearHistory`.
- **Private API**: `openAndInitializeDatabase`, `applySchemaIfNeeded`,
  `columnExists`, `migrateToV2`, `migrateToV3`, `migrateToV4`, `getUserVersion`,
  `setUserVersion`, `executeRaw`.
- **Dependencies**: SQLite3 (system), Foundation, AppKit (import), FileManager,
  UserDefaults, `LocalTrack` (for `CachedTrackRecord.toLocalTrack()`).
- **Consumers**: LocalLibraryManager, PlaylistManager, HistoryManager,
  LikedSongsManager, PlaylistLibraryView, SettingsPanel.
- **Lifecycle**: app-wide singleton, created on first touch.
- **State**: only `db` pointer + `dbQueue`; DB file persists on disk.
- **Events**: none emitted.
- **Thread-safety**: `SQLITE_OPEN_FULLMUTEX` makes sqlite3 handle its own locking
  (serialized mode). Additionally, only the history API group serializes through
  `dbQueue` (`recordHistoryItem` async; `fetchHistory`/`fetchHistoryCount`/
  `deleteHistoryItem`/`clearHistory` sync). All other APIs execute on the caller's
  thread with no explicit queue. Cross-queue mixing is safe because of FULLMUTEX, but
  `executeRaw("BEGIN TRANSACTION;")`/`COMMIT` groups are not wrapped in a single lock
  — see RISKS.
- **Relationships**: 1:1 with LocalLibraryManager (scan cache); consumed heavily by
  PlaylistManager; part of the DB layer under `Managers/`.
- **What would break if removed**: nothing else can persist library metadata,
  playlists, history, or liked songs; LocalLibraryManager scanning (0-AVURLAsset
  reuse path), PlaylistManager CRUD, HistoryManager, LikedSongsManager all collapse.

---

### FUNCTION ENTRIES — LocalDatabaseManager

#### `LocalDatabaseManager.databaseFileURL` (computed, ~190-197)
- **Purpose**: resolves + ensures the DB directory.
- **Output**: `URL` → `<Application Support>/Mooziac/library.sqlite3`.
- **Reads**: `FileManager.applicationSupportDirectory`, `.userDomainMask`.
- **Side effects**: creates `Application Support/Mooziac` if missing.
- **Async**: none.
- **Flow**: appSupport → append "Mooziac" → mkdir → append "library.sqlite3".

#### `LocalDatabaseManager.init` (199-201)
- **Purpose**: singleton bootstrap.
- **Calls**: `openAndInitializeDatabase()`.

#### `LocalDatabaseManager.deinit` (203-207)
- **Purpose**: close DB.
- **Calls**: `sqlite3_close`.

#### `openAndInitializeDatabase()` (210-229)
- **Purpose**: open DB (or recover), set PRAGMAs, apply schema.
- **Inputs**: none (uses `databaseFileURL.path`).
- **Outputs**: none; sets `self.db`.
- **Reads**: DB file at `~/Library/Application Support/Mooziac/library.sqlite3`.
- **Writes**: WAL/SHM files, schema.
- **Calls**: `executeRaw` (4 PRAGMAs), `applySchemaIfNeeded`, `recoverCorruptDatabase`.
- **Errors**: on open failure prints `[LocalDatabaseManager] Failed to open SQLite database at <path>` and calls `recoverCorruptDatabase`.
- **Async**: runs on caller (main) thread at init.
- **Flow**: open_v2 → store db → PRAGMAs → applySchemaIfNeeded.

#### `recoverCorruptDatabase()` (231-257)
- **Purpose**: nuke DB/WAL/SHM and rebuild from scratch.
- **Side effects**: DELETES `library.sqlite3`, `library.sqlite3-wal`, `library.sqlite3-shm`.
  Prints `[LocalDatabaseManager] Rebuilding database from scratch...`.
- **Calls**: `executeRaw`, `applySchemaIfNeeded`.
- **Errors**: silently ignores `removeItem` failures (`try?`).
- **Async**: none (caller thread). **Runs at startup on the main thread.**

#### `applySchemaIfNeeded()` (259-297)
- **Purpose**: version-gated DDL migration.
- **Calls**: `getUserVersion`, `executeRaw`, `setUserVersion`, `migrateToV2/V3/V4`.
- **Outputs**: none; mutates `user_version`.
- **Errors**: if a DDL batch fails, `setUserVersion` is skipped → retried next launch.

#### `columnExists(table:column:)` (299-317)
- **Purpose**: PRAGMA table_info scan.
- **Inputs**: table name, column name (both interpolated into query string).
- **Output**: `Bool`. Uses `sqlite3_prepare_v2`/`step`/`finalize`.

#### `migrateToV2()` (319-356)
- **Purpose**: add `yt_video_id` (idempotent) + create playlists/playlist_items.
- **Writes**: schema v2; prints `[LocalDatabaseManager] Schema migrated to v2 (playlists + yt_video_id)`.

#### `migrateToV3()` (358-380)
- **Purpose**: create listening_history; prints v3 log.

#### `migrateToV4()` (382-401)
- **Purpose**: create liked_songs; prints v4 log.

#### `getUserVersion()` (403-413) / `setUserVersion(_:)` (415-417)
- **Purpose**: read/write `PRAGMA user_version`. `setUserVersion` string-interpolates the
  version into SQL (safe — Int32).

#### `executeRaw(sql:)` (419-432)
- **Purpose**: raw `sqlite3_exec`. Returns `Bool`.
- **Errors**: prints `[LocalDatabaseManager] SQL Error: <err> in SQL: <sql>`; frees errMsg.
- **Called by**: nearly every other method (PRAGMAs, BEGIN/COMMIT, DDL, clearHistory).

#### `fetchAllRecords()` (435-483)
- **Purpose**: full `tracks` table dump keyed by file path.
- **Output**: `[String: CachedTrackRecord]` (key = file_path).
- **Reads**: all 12 columns of `tracks`.
- **Calls**: none.
- **Called by**: `LLM.enumerateFilesystemTracks` (scan reconciliation).
- **Flow**: prepare → step loop → build records → finalize.

#### `upsertTracks(_ records:)` (486-545)
- **Purpose**: batched upsert (ON CONFLICT(file_path)).
- **Inputs**: `[CachedTrackRecord]`.
- **Writes**: `tracks` rows. Uses prepared statement reused per record via reset/clear_bindings.
- **Async**: none; executes BEGIN → N steps → COMMIT on caller thread
  (called from LLM scan queue).
- **Errors**: if prepare fails → silent return (data loss). step results unchecked.

#### `deleteTracks(filePaths:)` (548-586)
- **Purpose**: delete tracks by file_path **and** cascade-clean playlist_items with
  `ref_type='local' AND ref_id = file_path`.
- **Writes**: `tracks`, `playlist_items`.
- **Flow**: BEGIN → per path: cleanupStmt then deleteStmt → COMMIT.
- **Errors**: silent if prepare fails.

#### `setLiked(filePath:isLiked:)` (589-601)
- **Purpose**: update `is_liked` matching `file_path = ? OR id = ?`.

#### `isLiked(filePath:)` (603-618)
- **Purpose**: read like state (`LIMIT 1`). Default `false`.

#### `migrateLikedKeysFromUserDefaultsIfNeeded()` (621-633)
- **Purpose**: one-time import of legacy liked keys.
- **Reads**: `UserDefaults` keys `Mooziac_SQLite_Liked_Migration_V1_Done` (guard flag)
  and `Mooziac_OfflineLikedKeys` (array).
- **Writes**: `UserDefaults` flag + `setLiked` for each legacy key.
- **Called by**: `LLM.enumerateFilesystemTracks`.

#### `addLikedSong(_ record:)` (636-664) / `removeLikedSong(videoId:)` (666-676)
- **Purpose**: liked_songs upsert (ON CONFLICT(video_id)) and delete.
- **Consumers**: LikedSongsManager.

#### `isLikedSong(videoId:)` (678-692)
- **Purpose**: existence check in liked_songs.

#### `setLikedSongSynced(videoId:)` (694-704)
- **Purpose**: marks row synced=1. Called by LikedSongsManager after upload.

#### `fetchLikedSongs()` (706-737) / `fetchUnsyncedLikedSongs()` (739-770)
- **Purpose**: fetch all / unsynced liked songs, `ORDER BY date_liked DESC`.
- **Consumer**: LikedSongsManager (sync upload).

#### `countLikedSongs()` (772-784)
- **Purpose**: `SELECT COUNT(*)`. Used for badge/count displays.

#### `setYTVideoID(_:for:)` (787-802)
- **Purpose**: attach a YouTube video id to a track row.
- **Called by**: `LLM.assignYTVideoID` after download finalization.

#### `filePaths(byVideoID:)` (804-820)
- **Purpose**: reverse lookup file paths for a video id. **DEAD CODE** — no callers
  found in the repo.

#### `fetchPlaylists()` (823-846)
- **Purpose**: all playlists + item count via LEFT JOIN; newest-updated first.

#### `createPlaylist(name:)` (848-866)
- **Purpose**: insert playlist; returns new UUID string or nil. `@discardableResult`.
- **Calls**: `sqlite3_step == SQLITE_DONE` for success check.

#### `renamePlaylist(id:name:)` (868-880)
- **Purpose**: update name + `updated_at`.

#### `deletePlaylist(id:)` (882-892)
- **Purpose**: delete; playlist_items cascade via FK (`ON DELETE CASCADE`).

#### `touchPlaylist(id:updatedAt:)` (894-905)
- **Purpose**: bump `updated_at` (defaults to now). Called by item mutations.

#### `fetchPlaylistItems(playlistID:)` (908-948)
- **Purpose**: items ordered by `sort_order ASC`.

#### `replacePlaylistItems(playlistID:items:)` (950-997)
- **Purpose**: atomic replace: BEGIN → DELETE by playlist_id → INSERT each → COMMIT →
  `touchPlaylist`. Used by `PM.createPlaylistFromCurrentQueue`.
- **Note**: caller-supplied `dateAdded` is written verbatim (line 989 binds `item.dateAdded`).

#### `appendPlaylistItem(_ item:)` (999-1028)
- **Purpose**: insert one item + `touchPlaylist(item.playlistID)`.

#### `removePlaylistItem(itemID:playlistID:)` (1030-1041)
- **Purpose**: delete by item id + touch playlist.

#### `reorderPlaylistItems(playlistID:orderedItemIDs:)` (1043-1062)
- **Purpose**: BEGIN → for each id set `sort_order = index` → COMMIT → touch playlist.

#### `recordHistoryItem(_ item:)` (1066-1136)
- **Purpose**: dedupe + insert history record, then prune to 1000.
- **Async**: `dbQueue.async { [weak self] ... }`. Deletes duplicates by 3 keys:
  yt_video_id, file_path, and normalized (title, artist) via
  `LOWER(TRIM(...))` compare. Inserts fresh row with `played_at = item.playedAt`.
  Prunes via subquery keeping top 1000 by `played_at DESC`.
- **Errors**: silent on prepare failure.
- **Called by**: HistoryManager.

#### `fetchHistory(limit:offset:)` (1138-1192)
- **Purpose**: pageable, deduped history (newest first). Default limit 200.
- **Async**: `dbQueue.sync { ... }` — blocking call.
- **Dedup**: subquery keeps row with MAX(played_at) per identity key
  (yt_video_id → file_path → title|artist).
- **Flow**: returns results after sync block.

#### `fetchHistoryCount()` (1194-1214)
- **Purpose**: `COUNT(DISTINCT CASE...)`. `dbQueue.sync`.

#### `deleteHistoryItem(id:)` (1216-1233)
- **Purpose**: delete single history row; returns Bool. `dbQueue.sync`.

#### `clearHistory()` (1235-1242)
- **Purpose**: `DELETE FROM listening_history;` returns Bool. `dbQueue.sync`.

---

### STRUCT ENTRIES — LocalDatabaseManager.swift

#### `CachedTrackRecord` (5-65)
Value type mirror of a `tracks` row. Fields: `id`, `filePath`, `title`, `artist`,
`album`, `duration: Double`, `dateAdded: Double`, `dateModified: Double`,
`fileSize: Int64`, `var isLiked: Bool`, `lrcPath: String?`, `var ytVideoId: String?`.
- `toLocalTrack()` (47-64): builds `LocalTrack` (artwork/artworkURL = nil, lrcURL from
  lrcPath, dateAdded from epoch seconds). This is the "0-AVURLAsset reuse" path used by
  LLM for unchanged files.
- **Consumers**: LDM/LLM.

#### `PlaylistRecord` (67-81)
Fields: `id`, `name`, `createdAt: Double`, `updatedAt: Double`, `itemCount: Int`.

#### `PlaylistItemRecord` (83-124)
Fields: `id` (default `UUID().uuidString`), `playlistID`, `sortOrder: Int`,
`refType: String`, `refID: String`, `ytVideoId: String?`, `title`, `artist` (default ""),
`artworkUrl` (default ""), `duration` (default ""), `isLiked` (default false),
`dateAdded: Double` (default now).

#### `HistoryRecord` (126-181, `Equatable`)
Fields: `id`, `title`, `artist`, `album`, `artworkUrl`, `ytVideoId: String?`,
`filePath: String?`, `playedAt: Double`, `duration: Double`,
`sourceType: String` — documented as `"online" or "local"` (line 136). Default `"online"`.
- `relativePlayedTimeString` (162-180): "Just now" (<60s), `Nm ago` (<3600s),
  `Nh ago` (<86400s), "Yesterday" (<172800s), else `DateFormatter` `.medium`/`.none`.
  `DateFormatter` created per call (perf + locale quirk, see RISKS).

---

## File 2 — `Sources/Mooziac/Managers/LocalLibraryManager.swift`

### FILE ENTRY

- **File**: `Sources/Mooziac/Managers/LocalLibraryManager.swift` (490 lines)
- **Purpose**: filesystem scanning of the music folder + App Support Offline folder,
  metadata extraction (AVURLAsset / ID3), reconciliation against the SQLite cache,
  artwork sidecar discovery, import/delete/like/search.
- **Subsystem**: `Managers/` — offline library.
- **What depends on it**:
  - `DownloadManager` (musicFolderURL, downloadingBaseURL, allTracks dedup,
    scanLibrary+assignYTVideoID after finalize)
  - `PlaylistManager` (libraryIndex from `allTracks`, isLiked, allTracks in appendLikedSong)
  - `NativeAudioPlayer`, `MainViewController`, `NowPlayingManager`, `PlayerControls`,
    `ContextMenu`, `HistoryManager`, `LikedSongsManager`, `LyricsManager`,
    `LocalTrack` (isLiked getter/setter)
  - Views: `OfflineLibraryView`, `PlaylistLibraryView`, `DynamicIslandPlayerView/{Core,SettingsPanel}`
- **What it depends on**: `LocalDatabaseManager` (cache), `NativeAudioPlayer`
  (priming, delete handling, like sync), `AppArtworkHelper`
  (via LocalTrack.artwork; removeCachedThumbnails), `NetworkMonitor` (offline priming),
  `LyricsManager` (cleanSongInfo), `NSWorkspace`.
- **Important imports**: `import AppKit`, `import Foundation`, `import AVFoundation`.
- **Classes defined**: `LocalLibraryManager` (public final, NSObject subclass).
- **Constants**:
  - `supportedExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "flac", "aiff", "aif", "ogg", "opus"]` (line 35)
  - Reconciliation tolerance `0.001` (line 207)
  - Search substring lowercased match (line 369-379)
- **Properties/state**:
  - `_allTracks: [LocalTrack]` (9), `stateLock: NSLock` (10), `scanLock: NSLock` (19),
    `isScanningInProgress: Bool` (20), `hasPendingScanRequest: Bool` (21),
    `activeCompletions: [([LocalTrack]) -> Void]` (22),
    `pendingCompletions: [([LocalTrack]) -> Void]` (23),
    `scanGeneration: UInt64` (24), `committedGeneration: UInt64` (25),
    `onLibraryUpdated: (([LocalTrack]) -> Void)?` (33),
    `queue = DispatchQueue(label: "com.mooziac.locallibrary", qos: .userInitiated)` (36)
- **Events**: posts `NotificationCenter` notification named `"Mooziac_LibraryUpdated"`
  (object = `[LocalTrack]`) on main (150). Also calls `onLibraryUpdated` closure.
- **Side effects**: creates `~/Music/Mooziac/`, `<Application Support>/Mooziac/Offline/`,
  custom downloads folder; writes/removes `YTM_downloadsFolder` in UserDefaults;
  deletes files; renames/copies files.
- **External APIs / system frameworks**: AVFoundation (`AVURLAsset`,
  `CMTimeGetSeconds`, `commonMetadata`, common keys `.commonKeyTitle/.commonKeyArtist/.commonKeyAlbumName`),
  Foundation `FileManager` (directory enumerator), AppKit (`NSWorkspace`), UserDefaults.
- **Files it communicates with**: `LocalDatabaseManager` (SQLite cache), the folders it
  scans, `LocalTrack`/`AppArtworkHelper` artwork cache, `LyricsManager`.

#### Filesystem scanning details (special attention)
- Directories scanned (`enumerateFilesystemTracks`, line 179):
  1. `musicFolderURL` — custom `YTM_downloadsFolder` (if set) else `~/Music/Mooziac/`
  2. `appSupportOfflineURL` — `~/Library/Application Support/Mooziac/Offline/`
- Enumerator: `FileManager.default.enumerator(at:includingPropertiesForKeys:
  [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
  options: [.skipsHiddenFiles, .skipsPackageDescendants])`.
- Extension filter via `supportedExtensions`; skips paths containing `"/.downloading/"`
  (in-flight downloads) (line 192); dedupes across the two folders by `foundPaths`.
- Files that are `isRegularFile != true` are skipped.
- **Reconciliation**: if a cached record exists and
  `abs(cached.dateModified - fileModDate) < 0.001` and `cached.fileSize == fileSize`
  → reuse `cached.toLocalTrack()` (0 AVURLAsset calls). Otherwise `extractMetadata`
  + stage upsert.
- Stale rows (in DB but no longer on disk) → `deleteTracks(filePaths:)`.
- New/modified rows → `upsertTracks(recordsToUpsert)` in one transaction.
- Post-scan: dedupe by `LyricsManager.cleanSongInfo(title).lowercased() + "|" + clean artist`
  signature; sort `dateAdded` descending.
- **Thread safety**: `stateLock` guards `_allTracks`; `scanLock` guards scan
  coordination/generation counters; actual scanning runs on serial `queue`.
  `scanGeneration`/`committedGeneration` implement last-write-wins (stale scans don't
  commit). Completion callbacks fire on `DispatchQueue.main`.

#### Metadata extraction details (`extractMetadata`, 269-347)
- Duration via `CMTimeGetSeconds(asset.duration)` guarded against NaN/Infinite.
- Title/artist/album from `asset.commonMetadata` common keys (stringValue).
- Filename fallback: `"Artist - Title"` split on `" - "` (2+ parts);
  otherwise whole filename. Empty artist → `"Local Audio"`.
- Sidecar `.lrc` file: same basename + `.lrc` extension.
- Sidecar artwork: checks `jpg`, `png`, `jpeg`, `webp` (in order, first match).
- `dateAdded` = contentModificationDate resource value (fallback `Date()`).
- `trackID` = the file path (line 331).
- Artwork is **not** embedded; `artwork: nil`, `artworkURL` = sidecar or nil.

#### Artwork caching (related)
- Not implemented in this file; delegated to `AppArtworkHelper` (verified in
  `Sources/Mooziac/Managers/AppArtworkHelper.swift`): cache dir
  `~/Library/Caches/Mooziac/Thumbnails` (AppArtworkHelper.swift:80-81),
  keys derived from `cacheKey(for:dateAdded:targetSize:)` default targetSize 128
  (AppArtworkHelper.swift:89). `deleteTrack` calls
  `AppArtworkHelper.shared.removeCachedThumbnails(for: track)`.

---

### CLASS ENTRY — `LocalLibraryManager` (public final, NSObject)

- **Purpose**: authoritative in-memory + SQLite-backed cache of local audio files.
- **Responsibilities**: scan coordination (coalescing), metadata extraction,
  like-toggle, import, delete, search, folder management.
- **init**: `private override init()` (79-83) → `ensureDirectoriesExist()` +
  `scanLibrary()`. Singleton `shared`.
- **Properties** (public): `shared`, `allTracks` (locked snapshot), `isScanning`,
  `onLibraryUpdated`, `musicFolderURL`, `defaultMusicFolderURL`,
  `appSupportOfflineURL`, `setMusicFolder`, `resetMusicFolderToDefault`,
  `ensureDirectoriesExist`, `scanLibrary`, `assignYTVideoID`, `search`, `importFiles`,
  `toggleLike`, `isLiked`, `openMusicFolderInFinder`, `deleteTrack`.
- **Private**: `_allTracks`, `stateLock`, `scanLock`, `isScanningInProgress`,
  `hasPendingScanRequest`, `activeCompletions`, `pendingCompletions`,
  `scanGeneration`, `committedGeneration`, `supportedExtensions`, `queue`,
  `performScan`, `enumerateFilesystemTracks`, `extractMetadata`.
- **Dependencies**: LocalDatabaseManager, AVFoundation, NativeAudioPlayer,
  NetworkMonitor, LyricsManager, AppArtworkHelper (indirect), UserDefaults.
- **Consumers**: DM, PM, NowPlayingManager, PlayerControls, ContextMenu, HistoryManager,
  LikedSongsManager, LyricsManager, LocalTrack, and all library views.
- **Lifecycle**: app-wide singleton; first scan kicks off at init.
- **State**: `_allTracks` (snapshot), scan flags/generation counters, completion arrays.
- **Events**: `"Mooziac_LibraryUpdated"` notification + `onLibraryUpdated` closure (main).
- **Relationships**: feeds PM's `PlaylistLibraryIndex`; consumed by DM for dedup and
  post-download rescan; DB via LDM.
- **What would break if removed**: offline library UI, playlist resolution to local
  tracks, download dedup + finalization, playback of offline tracks — all depend on it.

---

### FUNCTION ENTRIES — LocalLibraryManager

#### `allTracks` (computed, 12-16)
- **Purpose**: thread-safe snapshot. `stateLock.lock()` / unlock, returns copy of array.

#### `isScanning` (computed, 27-31)
- **Purpose**: thread-safe read of `isScanningInProgress` under `scanLock`.

#### `musicFolderURL` (computed, 38-52)
- **Purpose**: custom folder from `UserDefaults` key `"YTM_downloadsFolder"` (created if
  missing), else `~/Music/Mooziac/` (created if missing).
- **Reads**: `FileManager.musicDirectory` (.userDomainMask).
- **Side effects**: may create directories.

#### `defaultMusicFolderURL` (computed, 54-57)
- **Purpose**: always `~/Music/Mooziac/` (no UserDefaults). No directory creation.

#### `setMusicFolder(_ url:)` (59-63)
- **Purpose**: set + persist custom downloads folder; `try? createDirectory`; write
  `YTM_downloadsFolder`; trigger `scanLibrary()`.

#### `resetMusicFolderToDefault()` (65-68)
- **Purpose**: remove `YTM_downloadsFolder`; `scanLibrary()`.

#### `appSupportOfflineURL` (computed, 70-77)
- **Purpose**: `~/Library/Application Support/Mooziac/Offline/`, created if missing.

#### `init` (79-83)
- **Purpose**: bootstrap; calls `ensureDirectoriesExist()` then `scanLibrary()`.

#### `ensureDirectoriesExist()` (85-88)
- **Purpose**: force-evaluate `musicFolderURL` + `appSupportOfflineURL` (creates dirs).

#### `scanLibrary(completion:)` (91-113)
- **Purpose**: coalescing scan request. Behavior:
  - If a scan is in progress: callbacks go to `pendingCompletions`; sets
    `hasPendingScanRequest = true`; returns immediately.
  - Else: callbacks to `activeCompletions`; `isScanningInProgress = true`;
    `scanGeneration += 1`; calls `performScan(generation:)`.
- **Thread-safety**: all under `scanLock`.
- **Called by**: init, setMusicFolder, resetMusicFolderToDefault, importFiles,
  deleteTrack, DM (post-download), many views.
- **Calls**: `performScan`.

#### `performScan(generation:)` (115-167)
- **Purpose**: background scan worker.
- **Async**: `queue.async { [weak self] ... }` (serial `com.mooziac.locallibrary`,
  userInitiated).
- **Flow**: enumerate → (locked) commit only if `generation >= committedGeneration`;
  transfer active completions; if pending scan exists → promote pending completions,
  bump generation, schedule follow-up scan; else clear `isScanningInProgress`.
  Then on `DispatchQueue.main`: `onLibraryUpdated?(foundTracks)`, post
  `"Mooziac_LibraryUpdated"` notification with `object: foundTracks`; if offline
  (`!NetworkMonitor.shared.isReachable`) and `NativeAudioPlayer.shared.currentTrack == nil`,
  call `NativeAudioPlayer.shared.primeLastOrFirstTrack()`; fire completions.
  If `shouldRunNextScan`, recurse `performScan(generation: nextGeneration)`.
- **Writes**: `_allTracks` under `stateLock`; scan flags under `scanLock`.
- **Events**: posts `"Mooziac_LibraryUpdated"`.
- **Side effects**: may start audio priming when offline.

#### `enumerateFilesystemTracks()` (170-266)
- **Purpose**: full FS walk + SQLite reconciliation (see scanning details above).
- **Reads**: DB (fetchAllRecords, isLiked fallback), both scan dirs, resource values.
- **Writes**: LDM (deleteTracks for stale, upsertTracks for new/modified).
- **Calls**: `LocalDatabaseManager.fetchAllRecords`,
  `migrateLikedKeysFromUserDefaultsIfNeeded`, `extractMetadata`,
  `LocalDatabaseManager.deleteTracks`, `upsertTracks`, `LyricsManager.cleanSongInfo`.
- **Output**: deduped, dateAdded-sorted `[LocalTrack]`.
- **Async**: executes on `queue` (called from `performScan`).

#### `extractMetadata(from:isLiked:ytVideoId:)` (269-347)
- **Purpose**: build `LocalTrack` from AVURLAsset metadata + sidecars (see details above).
- **Inputs**: fileURL, isLiked, ytVideoId.
- **Output**: `LocalTrack` (id = path, artwork nil, artworkURL = sidecar jpg/png/jpeg/webp,
  lrcURL = `.lrc` sidecar).
- **Called by**: `enumerateFilesystemTracks`.
- **Errors**: duration NaN/Infinite guarded; no AVAsset error handling (see RISKS).

#### `assignYTVideoID(_:toFileAt:)` (350-366)
- **Purpose**: after download finalization, map video id → file path in DB and in-memory.
- **Writes**: LDM `setYTVideoID`, `_allTracks` (under stateLock) for matching path/id.
- **Events**: `onLibraryUpdated` on main with snapshot.
- **Called by**: DM executeDownloadTask (inside scanLibrary completion).

#### `search(query:)` (369-379)
- **Purpose**: sub-millisecond substring search across title/artist/album (lowercased).
- **Output**: `[LocalTrack]` (snapshot if query empty).

#### `importFiles(from:completion:)` (382-408)
- **Purpose**: copy files into music folder.
- **Async**: `queue.async`. For each source: accept supported audio ext or `"lrc"`;
  target = destFolder + lastPathComponent; if target exists → remove; `copyItem`;
  count non-lrc files. Then `scanLibrary { _ in completion(importedCount) }`.
- **Errors**: prints `[LocalLibraryManager] Error copying <name>: <error>`; continues.

#### `toggleLike(for trackID:)` (411-434)
- **Purpose**: flip like in DB + in-memory snapshot; sync NativeAudioPlayer if the
  active track matches; fire `onLibraryUpdated` (main).
- **Calls**: `LDM.isLiked`, `LDM.setLiked`, `NativeAudioPlayer.updateLikedState`.
- **Note**: `LocalTrack.isLiked` setter (LocalTrack.swift:26-35) also routes through
  `toggleLike`, so setting `isLiked` on a track triggers this path.

#### `isLiked(trackID:)` (436-438)
- **Purpose**: delegate to `LDM.isLiked(filePath:)`.

#### `openMusicFolderInFinder()` (441-443)
- **Purpose**: `NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: musicFolderURL.path)`.

#### `deleteTrack(_:completion:)` (446-489)
- **Purpose**: remove file + lrc sidecar + DB row + artwork cache + rescan.
- **Async**: player cleanup on main first (`NativeAudioPlayer.handleTrackDeleted`),
  then `queue.async`: remove audio file (`try FileManager.removeItem`), remove
  `.lrc` sidecar (`try?`), `LDM.deleteTracks([path])`,
  `AppArtworkHelper.removeCachedThumbnails`, `scanLibrary`, completion(true) on main.
- **Errors**: on failure → prints `[LocalLibraryManager] Failed to delete track: <error>`,
  still deletes DB row + artwork cache, rescans, completion(false).

---

## File 3 — `Sources/Mooziac/Managers/PlaylistManager.swift`

### FILE ENTRY

- **File**: `Sources/Mooziac/Managers/PlaylistManager.swift` (865 lines)
- **Purpose**: playlist business logic: CRUD, item add/append/reorder/remove,
  history/liked-song capture, queue capture, playback orchestration (local + online),
  summaries.
- **Subsystem**: `Managers/` — playlists.
- **What depends on it**:
  - `MainViewController`, `NowPlayingManager/ObserverBridge`, `PlayerControls`,
    `HistoryManager`, `LikedSongsManager`
  - Views: `OfflineLibraryView`, `PlaylistLibraryView`, `DynamicIslandPlayerView/SettingsPanel`
- **What it depends on**: `LocalDatabaseManager` (all persistence), `LocalLibraryManager`
  (index + allTracks), `NativeAudioPlayer` (currentTrack, playNext, appendToQueue,
  repeatMode), `NowPlayingManager` (currentState, engineMode, repeatMode,
  playOfflineTrack, switchToOnlineMode, evaluateJS, fetchUpNextSnapshot via Queue.swift),
  `NetworkMonitor` (resolve/planDownloads), `StatusItemManager` (mainViewController),
  `UserDefaults`, `LyricsManager` (cleanSongInfo), `AppKit`.
- **Important imports**: `import AppKit`, `import Foundation` (no AVFoundation/SQLite).
- **Classes defined**: `PlaylistManager` (public final, NSObject) + top-level struct
  `PlaylistLibraryIndex`. Nested: `PlaylistItemSource`, `PlaylistPlayResult`,
  `PlaylistDownloadPlan`, `ActivePlaylistPlaybackContext`.
- **Constants**:
  - Accent color `NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)` (cyan) and SF
    Symbol `"music.note.list"` used by `metaFor`/`iconAndColorFor` (44-50).
  - Preset playlist names set (97-101): `"chill vibes", "workout & gym", "night drive",
    "deep focus", "lo-fi beats", "top hits", "rock & indie", "rainy acoustic",
    "morning energy", "relax & sleep", "party & dance"`.
  - UserDefaults guard key `"Mooziac_CleanedPresetPlaylists_v1"` (94).
  - Timeout literals: online fallback URL delay 1.5s / 0.3s (844, 848).
- **Properties/state**:
  - `_libraryIndex: PlaylistLibraryIndex?` (52), `indexLock: NSLock` (53),
    `summaryCache: [String: (countText:String, durationText:String)]` (54),
    `summaryCacheLock: NSLock` (55),
    `public private(set) var activeContext: ActivePlaylistPlaybackContext?` (704).
- **Events**: **none posted** by PM itself; it *observes* `"Mooziac_LibraryUpdated"`
  (registered in init, main queue) to invalidate library index + summaries.
- **Side effects**: `cleanPresetPlaylistsOnceIfNeeded` deletes empty preset playlists
  one time; JS injection into YTM web view (`addToQueue` custom event, `loadVideoById`).
- **External APIs / system frameworks**: WebKit JS via NowPlayingManager/MainViewController
  web view; `URL`/`URLRequest` for `music.youtube.com/watch?...`; `NetworkMonitor`.
- **Files it communicates with**: LDM (persistence), LLM (index), NativeAudioPlayer,
  NowPlayingManager, StatusItemManager (`mainViewController.webViewContainer.webView`),
  MainViewController (webViewContainer.selectSongTab).

---

### CLASS ENTRY — `PlaylistManager` (public final, NSObject)

- **Purpose**: high-level playlist operations + playlist playback engine.
- **Responsibilities**: CRUD passthrough, item add (local/history/liked/current-playing),
  queue capture, dedupe checks, resolution of playlist items to local/online/unavailable,
  download planning, playback start/next/prev with active context, online fallback,
  summaries, current-track membership checks.
- **init**: `private override init()` (84-91): `cleanPresetPlaylistsOnceIfNeeded()`;
  registers NotificationCenter observer for `"Mooziac_LibraryUpdated"` (main queue)
  → `invalidateLibraryIndex()` + `invalidateAllSummaries()`.
- **Properties**: `shared`, `activeContext` (public private(set), NOT lock-guarded),
  `hasActiveContext` (computed), `currentNowPlayingVideoID` (computed).
- **Public API**: `metaFor`, `iconAndColorFor`, `invalidateSummary`, `fetchPlaylists`,
  `createPlaylist`, `renamePlaylist`, `deletePlaylist`, `fetchPlaylistItems`,
  `appendPlaylistItem`, `removeItem`, `reorderItems`, `appendLocalTracks`,
  `appendTrack`, `appendHistoryItem`, `appendLikedSong`, `createPlaylistFromCurrentQueue`,
  `appendCurrentPlayingTrack`, `isCurrentTrackInPlaylist`,
  `removeCurrentPlayingTrackFromPlaylist`, `toggleCurrentPlayingTrack`, `playNext`,
  `addToQueue`, `appendCurrentTrack`, `currentNowPlayingVideoID`, `resolve`,
  `localTracks`, `planDownloads`, `play`, `shufflePlay`, `summaryForPlaylist`,
  `activeContext`, `hasActiveContext`, `clearActiveContext`, `startPlaylist`,
  `playTrackAtCurrentContextIndex`, `playNextTrackInPlaylist`,
  `playPreviousTrackInPlaylist`, `playOnlineVideo`, `formattedDuration`.
- **Private API**: `libraryIndex`, `invalidateLibraryIndex`, `invalidateAllSummaries`,
  `cleanPresetPlaylistsOnceIfNeeded`, `resolve(_:index:)`, `buildLocalQueue`,
  `rebuildLocalQueue`.
- **Dependencies**: LDM, LLM, NativeAudioPlayer, NowPlayingManager, NetworkMonitor,
  StatusItemManager/MainViewController (web view), UserDefaults.
- **Consumers**: MainViewController, ObserverBridge, PlayerControls, HistoryManager,
  LikedSongsManager, library views, SettingsPanel.
- **Lifecycle**: singleton; library index lazily built + invalidated on updates.
- **State**: `_libraryIndex`, `summaryCache`, `activeContext`.
- **Events**: observes `"Mooziac_LibraryUpdated"`. Does not post notifications.
- **Relationships**: persistence → LDM; index → LLM; playback → NativeAudioPlayer +
  NowPlayingManager; web → StatusItemManager.mainViewController.webViewContainer.webView.
- **What would break if removed**: all playlist UI operations, playlist playback,
  "add current track to playlist", download-plan UI, history/liked-songs → playlist
  capture.

---

### FUNCTION ENTRIES — PlaylistManager

#### `PlaylistLibraryIndex` (struct, 4-24)
- **Purpose**: derived index maps for resolution: `byFilePath`, `byVideoId`, `byId`
  (byId covers `byFilePath` ids too). Built from `[LocalTrack]`.
- **Note**: `byId` keyed by `track.id` (which for local tracks = file path).

#### `metaFor(playlistName:)` / `iconAndColorFor(playlistName:)` (44-50)
- **Purpose**: static metadata for playlist list UI. Return hardcoded
  `("", "music.note.list", cyan)` / `("music.note.list", cyan)`. Playlist name input
  ignored (dead parameter, hardcoded output).

#### `libraryIndex()` (57-64)
- **Purpose**: lazily build + cache index from `LocalLibraryManager.shared.allTracks`,
  guarded by `indexLock`.

#### `invalidateLibraryIndex()` (66-70) / `invalidateSummary(for:)` (72-76) / `invalidateAllSummaries()` (78-82)
- **Purpose**: cache invalidation, each lock-guarded.

#### `init` (84-91)
- **Purpose**: preset cleanup + library-update observer (main queue).

#### `cleanPresetPlaylistsOnceIfNeeded()` (93-109)
- **Purpose**: one-time cleanup (guard `"Mooziac_CleanedPresetPlaylists_v1"`) of empty
  preset playlists (names list above, `itemCount == 0`) → `deletePlaylist`.
- **Side effects**: writes guard flag to UserDefaults, deletes DB rows.

#### `fetchPlaylists()` (113-115) / `createPlaylist(name:)` (117-120) / `renamePlaylist(id:name:)` (122-124) / `deletePlaylist(id:)` (126-128)
- **Purpose**: thin passthroughs to LDM.

#### `fetchPlaylistItems(playlistID:)` (132-134)
- **Purpose**: passthrough to LDM.

#### `appendPlaylistItem(_:to:)` (136-139)
- **Purpose**: passthrough + invalidate summary.

#### `removeItem(itemID:from:)` (141-156)
- **Purpose**: remove item + invalidate summary; if the active context is this playlist,
  refetch items, preserve current item index (search by id), clamp index to bounds,
  rebuild local queue, write back `activeContext`.

#### `reorderItems(playlistID:orderedItemIDs:)` (158-171)
- **Purpose**: persist order + invalidate summary; if active context is this playlist,
  refetch items, re-resolve current index by id, rebuild local queue.

#### `appendLocalTracks(_:to:)` (173-196)
- **Purpose**: batch-append local tracks; skips duplicates by `refType=="local" &&
  refID == file path`. `sortOrder` continues from existing count.

#### `appendTrack(to:track:)` (198-223)
- **Purpose**: single-track append with dedupe (refID or track.id; ytVideoId; title
  case-insensitive). Returns `(success, message)`; `"Already in playlist"` on dup,
  `"Added \"<title>\" to playlist"` on success.

#### `appendHistoryItem(to:item:)` (225-255)
- **Purpose**: append from history. refType `"local"` if `sourceType=="local"` or
  filePath non-empty else `"yt"`. refID = filePath (or item.id) for local, else
  ytVideoId (or item.id). Dedupe by refID, ytVideoId, or (title+artist) case-insensitive.

#### `appendLikedSong(to:record:)` (257-291)
- **Purpose**: append from LikedSongRecord; resolves local-ness by matching
  `ytVideoId == record.videoId` or `fileURL.path == record.videoId` against
  `LocalLibraryManager.shared.allTracks`. refType local/yt accordingly. Sets
  `isLiked: true`. Dedupe by refID / ytVideoId / (title+artist).

#### `createPlaylistFromCurrentQueue(name:completion:)` (295-319)
- **Purpose**: capture NowPlayingManager up-next queue into a new playlist.
- **Async**: `NowPlayingManager.shared.fetchUpNextSnapshot { snapshot in ... }`
  (snapshot built on web layer). Creates playlist, maps `snapshot.items` → items with
  refType `"yt"`, refID = videoId, ytVideoId = videoId (nil if empty),
  `replacePlaylistItems`, completion(playlistID, count).

#### `appendCurrentPlayingTrack(to:)` (321-410)
- **Purpose**: add the currently-playing song to a playlist. Three paths:
  1. Offline/local: `NativeAudioPlayer.shared.currentTrack` + (engineMode == .offline
     OR state.title empty/"Not Playing") → local item.
  2. Online: NowPlayingManager `currentState` with fallbacks to UserDefaults
     `"YTM_lastTitle"`, `"YTM_lastArtist"`, `"YTM_lastVideoId"`, `"YTM_lastArtwork"` —
     refType `"yt"`, refID = videoId (or title if empty).
  3. Fallback: NativeAudioPlayer.currentTrack.
  Returns `"No song currently playing"` if nothing matched.

#### `isCurrentTrackInPlaylist(playlistID:)` (412-442)
- **Purpose**: membership check mirroring the same three-path logic.

#### `removeCurrentPlayingTrackFromPlaylist(playlistID:)` (444-482)
- **Purpose**: find current-playing item and remove it. Returns `(removed, message)`;
  `"Track not found in playlist"` if absent.

#### `toggleCurrentPlayingTrack(in:)` (484-492)
- **Purpose**: add-or-remove toggle; returns `(added, message)`.

#### `playNext(item:)` (494-513)
- **Purpose**: insert item right after current in active context (dedupe same id),
  rebuild local queue; then resolve — `.local` → `NativeAudioPlayer.playNext(track:)`;
  `.online`/`.unavailable` → no-op.

#### `addToQueue(item:)` (515-528)
- **Purpose**: `.local` → `NativeAudioPlayer.appendToQueue(track:)`; `.online` →
  JS dispatch into YTM player bar:
  `document.querySelector('ytmusic-player-bar').dispatchEvent(new CustomEvent('addToQueue', { detail: { videoId: '<vid>' } }))`
  via `NowPlayingManager.evaluateJS`. `.unavailable` → no-op.

#### `appendCurrentTrack(to:)` (530-532)
- **Purpose**: alias for `appendCurrentPlayingTrack` (retained for compatibility).

#### `currentNowPlayingVideoID` (computed, 534-537)
- **Purpose**: `UserDefaults["YTM_lastVideoId"]` or nil. **DEAD CODE** — no callers.

#### `resolve(_:)` (541-543) / `resolve(_:index:)` (545-577)
- **Purpose**: classify an item as `.local(LocalTrack)`, `.online(videoId)`, or
  `.unavailable`.
- Local: index.byFilePath/ById first, then by ytVideoId.
- yt/online: prefer ytVideoId, else refID; if a local track matches byVideoId/ById → local;
  else if `NetworkMonitor.shared.isReachable` → online; else unavailable.

#### `localTracks(in:)` (579-586)
- **Purpose**: resolved local tracks of a playlist. **DEAD CODE** — no callers found.

#### `planDownloads(for:)` (594-622)
- **Purpose**: produce `PlaylistDownloadPlan` (`toDownload`, `alreadyLocal`,
  `offlineBlocked`). Unavailable + yt + reachable → toDownload; unavailable + offline →
  offlineBlocked; unresolved local fallback counts as alreadyLocal.
- **Consumers**: SettingsPanel, PlaylistLibraryView (download-all UI).

#### `play(playlistID:completion:)` (626-635)
- **Purpose**: sequential play of playlist. Empty → `PlaylistPlayResult(started:false,
  message:"Playlist is empty")`. Calls `startPlaylist(shuffle: false)`.

#### `shufflePlay(playlistID:completion:)` (637-646)
- **Purpose**: shuffled play; message `"Shuffling playlist"`.

#### `summaryForPlaylist(_:)` (648-692)
- **Purpose**: cached `(countText, durationText)`. Count: `"N tracks"` / `"1 track"`.
  Duration: resolves local track duration from index; else parses `item.duration`
  "MM:SS" or "HH:MM:SS" text. Output `"<N> mins"`, `"<h> hr <m> mins"`, `"<h> hr"`.

#### `buildLocalQueue(for:index:)` (714-724)
- **Purpose**: ordered local queue + `[itemID: queueIndex]` map from items.

#### `rebuildLocalQueue(for:)` (726-731)
- **Purpose**: mutates context in place.

#### `startPlaylist(playlistID:startingAt:shuffle:)` (733-763)
- **Purpose**: load items; if shuffle and a startID given → pin startID at index 0 then
  shuffle rest; if shuffle only → shuffle all. Compute startIndex. Build context,
  set `activeContext`, call `playTrackAtCurrentContextIndex()`.

#### `playTrackAtCurrentContextIndex()` (765-787)
- **Purpose**: play item at `ctx.currentIndex`. Invalid → `activeContext = nil`.
  - `.local`: build remaining local queue from `localQueueIndexByItemID` onward,
    dispatch on main `NowPlayingManager.shared.playOfflineTrack(track, in: localQueue)`.
  - `.online`: `playOnlineVideo(videoId:)`.
  - `.unavailable`: skip → `playNextTrackInPlaylist()`.

#### `playNextTrackInPlaylist()` (789-807)
- **Purpose**: if `NowPlayingManager.repeatMode == .one` → replay current. Else advance
  index; at end → `activeContext = nil`, return false (autoplay takes over).

#### `playPreviousTrackInPlaylist()` (809-820)
- **Purpose**: step back one index; false if already at 0.

#### `playOnlineVideo(videoId:)` (822-854)
- **Purpose**: online fallback playback. `NowPlayingManager.switchToOnlineMode()`; on
  main, get `StatusItemManager.shared?.mainViewController`; evaluate JS
  `loadVideoById('<vid>')` on `#movie_player`/`.html5-video-player`, then `playVideo()`.
  If JS returns false: load `https://music.youtube.com/watch?v=<vid>&list=RDAMVM<vid>`
  and `selectSongTab()` after 1.5s; else `selectSongTab()` after 0.3s.

#### `formattedDuration(_ seconds:)` (858-864)
- **Purpose**: `%d:%02d` minutes:seconds; empty string for non-finite/≤0.

---

## File 4 — `Sources/Mooziac/Managers/DownloadManager.swift`

### FILE ENTRY

- **File**: `Sources/Mooziac/Managers/DownloadManager.swift` (1013 lines)
- **Purpose**: offline-download pipeline via external `yt-dlp` subprocess; queue,
  progress, cancellation, validation, finalization into the music folder, yt_video_id
  registration.
- **Subsystem**: `Managers/` — downloads.
- **What depends on it**:
  - `Views/Libraries/PlaylistLibraryView.swift`, `Views/Libraries/OfflineLibraryView.swift`,
    `Views/Player/DynamicIslandPlayerView/Core.swift`, `.../SettingsPanel.swift`,
    `Core/NowPlayingManager/PlayerControls.swift`
- **What it depends on**: `LocalLibraryManager` (musicFolderURL, allTracks dedup,
  scanLibrary, assignYTVideoID), `LyricsManager` (cleanSongInfo, fetchRawSyncedLRC),
  `Foundation` (Process/Pipe), AVFoundation (validation), Darwin (`kill`, SIGTERM/SIGKILL),
  NetworkMonitor (indirect, through library). Requires external binaries:
  **yt-dlp** and **ffmpeg** (must be installed; error message tells user
  `brew install yt-dlp ffmpeg`).
- **Important imports**: `import AppKit`, `import Foundation`, `import AVFoundation`,
  `import Darwin`.
- **Classes defined**: `DownloadManager` (public final, NSObject). Top-level
  `DownloadStatus` enum + `DownloadProgressInfo` struct; nested `QueueTask`.
- **Constants**:
  - `downloadTimeout: TimeInterval = 1200` (line 69) — 20 min.
  - Progress coalescing: min interval `0.08`s, min delta `0.02` (2%), force-flush at
    `>= 0.99` (568-569).
  - `currentItemCountInBatch` etc. reset to `-1.0` sentinel for `lastBroadcastProgress`.
  - Audio validation: min file size `10240` bytes, min duration `> 1.0`s (957, 963).
  - `supportedAudioExts` for validation: `["m4a", "mp3", "aac", "wav", "flac", "ogg", "opus"]` (947).
  - Video id length `11` (368, 992).
  - ETA rewrite when `00:MM:SS` → `"Ns"` (926-929).
  - Error message truncation to 60 chars (825).
  - `makeProcessEnvironment` PATH candidate list (698-711) and yt-dlp candidate paths
    (762-772) / ffmpeg candidate dirs (786-791).
- **Properties/state**:
  - Public private(set): `isDownloading`, `currentDownloadTitle`, `currentProgress`,
    `currentETA`, `currentSpeed`, `currentItemCountInBatch`, `totalBatchCount`.
  - Public closures: `onDownloadStatusChanged: ((Bool, String) -> Void)?`,
    `onProgressUpdated: ((DownloadProgressInfo) -> Void)?`.
  - Private: `workQueue` (serial, userInitiated), `timeoutQueue` (serial, utility),
    `queueLock: NSLock`, `tasksQueue: [QueueTask]`, `activeTask: QueueTask?`,
    `currentActiveJobDirURL: URL?`, `lastProgressNotificationTime`, `lastBroadcastProgress`,
    `activeProcess: Process?`, `ytDlpPath: String?`, `cancelledTaskIDs: Set<String>`.
- **Events** (notifications posted):
  - `DownloadManager.progressNotification = NSNotification.Name("Mooziac_DownloadProgress")` (27)
  - `DownloadManager.queueNotification = NSNotification.Name("Mooziac_DownloadQueueChanged")` (28)
- **Side effects**: subprocess spawn, kill/terminate; creates/removes
  `~/Music/Mooziac/.downloading/<jobId>/` sandboxes; moves files into music folder;
  writes `.lrc` lyric files; prints progress/error logs.
- **External APIs / system frameworks**: Foundation `Process`, `Pipe`, `FileHandle`
  (readabilityHandler), Darwin `kill(pid, SIGTERM/SIGKILL)`, AVFoundation
  (`AVURLAsset.isPlayable`, duration), `FileManager`, `URLSession`-free (artwork fetched
  via `Data(contentsOf:)`).
- **Files it communicates with**: LLM (`musicFolderURL`, `allTracks`, `scanLibrary`,
  `assignYTVideoID`), LyricsManager (LRC), LocalDatabaseManager (via LLM);
  `~/Music/Mooziac/` and `~/Music/Mooziac/.downloading/`.

---

### CLASS ENTRY — `DownloadManager` (public final, NSObject)

- **Purpose**: serial download queue that shells out to yt-dlp, parses progress,
  validates output, finalizes into the library, and registers the mapping.
- **Responsibilities**: queueing/dedup; yt-dlp resolution; subprocess execution with
  streamed progress; timeout + cancellation; audio validation; artwork staging;
  LRC fetch; post-download library rescan + yt_video_id assignment; status broadcasting.
- **init**: `private override init()` (83-86) → `cleanupStaleDownloads()` (async).
- **Properties**: as listed above.
- **Public API**: `shared`, `progressNotification`, `queueNotification`, `remainingQueueCount`,
  `onDownloadStatusChanged`, `onProgressUpdated`, `downloadingBaseURL`,
  `cleanupStaleDownloads`, `statusFor`, `downloadTrack`, `queueTrack`, `queueTracks`,
  `cancelQueuedTask`, `cancelTask`, `cancelAllDownloads`, static `makeProcessEnvironment`,
  `extractErrorMessage`, `parseYtDlpProgress`, `extractVideoID`.
- **Private API**: `librarySignature`, `processNextQueueTask`, `scheduleTimeout`,
  `handleTaskTimeout`, `executeDownloadTask`, `handleStreamingProgress`, `finishTask`,
  `broadcastProgress`, `broadcastQueueStatus`, `runShellPathResolution`,
  `resolveYtDlpPath`, `resolveFFmpegLocation`, `validateJobAudioFile`, `cleanupJobDir`.
- **Dependencies**: LLM, LyricsManager, AVFoundation, Darwin, external yt-dlp/ffmpeg.
- **Consumers**: OfflineLibraryView, PlaylistLibraryView, PlayerControls,
  DynamicIslandPlayerView Core/SettingsPanel.
- **Lifecycle**: singleton; one active download at a time (serial queue).
- **State**: `tasksQueue`, `activeTask`, `activeProcess`, `cancelledTaskIDs`,
  `currentActiveJobDirURL`, progress display vars, last-notification timestamps.
- **Events**: posts `"Mooziac_DownloadProgress"` and `"Mooziac_DownloadQueueChanged"`.
- **Relationships**: finalizes through LLM (scan + assignYTVideoID) which persists via LDM.
- **What would break if removed**: all offline-download capability and progress UI.

---

### FUNCTION ENTRIES — DownloadManager

#### `DownloadStatus` (enum, 6-11)
Cases: `.queued`, `.downloading(progress: Double, eta: String, speed: String)`,
`.completed`, `.failed(String)`. `Equatable`.

#### `DownloadProgressInfo` (struct, 13-22)
Fields: `id`, `videoId: String?`, `title`, `artist`, `progress`, `eta`, `speed`,
`status: DownloadStatus`. Note: `artist` is always `""` when broadcast (line 638).

#### `QueueTask` (nested struct, 30-41)
Fields: `id`, `urlOrVideoId`, `title`, `artist`, `artworkUrl`, `progress: Double = 0.0`,
`eta = ""`, `speed = ""`, `status = .queued`, `completion: ((Bool, String) -> Void)?`.

#### `remainingQueueCount` (computed, 51-55)
- **Purpose**: `tasksQueue.count + (activeTask != nil ? 1 : 0)`, lock-guarded.

#### `downloadingBaseURL` (computed, 74-81)
- **Purpose**: `<musicFolder>/.downloading/` directory, created if missing.

#### `init` (83-86)
- **Purpose**: startup stale-sandbox cleanup.

#### `cleanupStaleDownloads()` (89-104)
- **Purpose**: remove leftover `.downloading/<jobId>` dirs (except `currentActiveJobDirURL`).
- **Async**: `workQueue.async`. Logs `[DownloadManager] Cleaned stale download sandbox: <name>`.
- **Called by**: init (and can be called manually — public).

#### `statusFor(id:videoId:)` (107-138)
- **Purpose**: query active/queued status for UI. Matches by `id` or substring of
  `urlOrVideoId`. Returns `DownloadProgressInfo?` (queued entries: progress 0).

#### `downloadTrack(urlOrVideoId:title:artist:artworkUrl:completion:)` (141-156)
- **Purpose**: convenience wrapper → `queueTrack` with new UUID.

#### `queueTrack(id:urlOrVideoId:title:artist:artworkUrl:completion:)` (158-213)
- **Purpose**: enqueue a single task.
- **Flow**: clean title/artist via `LyricsManager.cleanSongInfo`; extract video id.
  Dedup against library: match by `ytVideoId`, or `title` (or cleanTitle) + artist
  (or cleanArtist, empty artist is a wildcard). If exists → broadcast `.completed` 1.0,
  call completion(`true, "Already in offline library"`), return.
  Under `queueLock`: skip if id already active/queued. Append task, bump `totalBatchCount`.
  On main: broadcast `.queued` + queue status. Then `processNextQueueTask()`.
- **Thread-safety**: library dedup happens **outside** any lock (reads
  `LocalLibraryManager.shared.allTracks` snapshot — safe).

#### `queueTracks(_ tracks:)` (216-283)
- **Purpose**: batch enqueue with one-shot dedup index.
- **Flow**: build `existingVideoIds` + `existingSignatures`
  (`librarySignature(title,artist)`) from library ONCE. Under `queueLock`: skip dups
  (videoId in library, signature in library, or id already queued); broadcast `.completed`
  for dups; append new tasks and broadcast `.queued`; update `totalBatchCount`.
  After unlock: broadcast queue status; if `newlyQueuedCount > 0` → `processNextQueueTask()`.
- **Note**: tasks created here have `completion: nil` (no callback).

#### `librarySignature(title:artist:)` (static, 285-289)
- **Purpose**: `"<cleanTitle>|<cleanArtist>"` lowercased dedup signature.

#### `processNextQueueTask()` (292-328)
- **Purpose**: serial queue worker.
- **Async**: `workQueue.async`. Under `queueLock`: return if `activeTask != nil`; if queue
  empty → reset state on main (`isDownloading=false`, clear fields, `totalBatchCount=0`,
  `currentItemCountInBatch=0`, `lastBroadcastProgress=-1.0`,
  `onDownloadStatusChanged?(false, "")`, `broadcastQueueStatus`), return. Else
  `removeFirst`, set `.downloading(0.0)`, set `activeTask`, increment
  `currentItemCountInBatch`, unlock. Then `scheduleTimeout(for:)` + `executeDownloadTask(task:)`.
- **Calls**: `scheduleTimeout`, `executeDownloadTask`, `broadcastQueueStatus`.

#### `scheduleTimeout(for:)` (330-334)
- **Purpose**: `timeoutQueue.asyncAfter(deadline: .now() + 1200s)` → `handleTaskTimeout`.

#### `handleTaskTimeout(taskID:)` (336-351)
- **Purpose**: kill hung downloads. Guard: task is active and process exists. `kill(pid,
  SIGTERM)`; after 3s on `DispatchQueue.global()` force `SIGKILL` if still running.
  Logs `[DownloadManager] Download timed out after 1200s, terminating yt-dlp`.

#### `executeDownloadTask(task:)` (354-562)
- **Purpose**: run yt-dlp for one task (core pipeline).
- **Query resolution** (359-375): if `urlOrVideoId` is http(s): keep as-is when it
  contains `watch?v=` or `youtu.be/`; else if cleanT non-empty → `"ytsearch1:<artist> - <title>"`;
  else raw URL. If bare 11-char id → `"https://music.youtube.com/watch?v=<id>"`. Else if
  cleanT → `ytsearch1:...`. Else `finishTask(success:false, "Invalid track query")`.
- **Flow**:
  1. Main: set `isDownloading=true`, title, reset progress fields, fire
     `onDownloadStatusChanged?(true, "Downloading <t>...")`, broadcast 0.05 downloading
     + queue status.
  2. `musicDir = LLM.shared.musicFolderURL`; `safeFilename =
     "<artist or Unknown> - <title or Track>"` with `/` and `:` replaced by `-`.
  3. Create sandbox `jobDir = downloadingBaseURL/<UUID>` (error → finish fail
     "Failed to create sandbox").
  4. `outputTemplate = jobDir/<safeFilename>.%(ext)s`. Resolve yt-dlp path
     (fail → cleanup + `"yt-dlp not found. Run: brew install yt-dlp ffmpeg"`).
  5. yt-dlp args (415-430):
     `--newline --no-update --extractor-args youtube:player_client=mweb,web_safari,tv_embedded,web --no-playlist -x --audio-format m4a --audio-quality 0 --embed-thumbnail --embed-metadata`
     + optional `--ffmpeg-location <dir>` + `-o <template> <query>`.
     Environment via `makeProcessEnvironment()`.
  6. Store `activeProcess` under lock. Merge stdout+stderr into one `Pipe`; `readabilityHandler`
     buffers lines, parses progress via `parseYtDlpProgress`, calls
     `handleStreamingProgress`.
  7. `process.run()` then blocking `process.waitUntilExit()` (on workQueue — fine).
     Clear readabilityHandler. Under lock: check `cancelledTaskIDs`/active match, clear
     cancelled id, null `activeProcess` if same. If cancelled or terminationStatus 15/-15 →
     `cleanupJobDir`, return (no finish).
  8. Non-zero exit → cleanup + `extractErrorMessage` (or `"Download failed. Check connection."`),
     log last 15 lines, `finishTask(success:false)`.
  9. `validateJobAudioFile(in: jobDir)` → else cleanup + finish fail
     `"Downloaded file corrupted or invalid"`.
  10. Stage artwork: `jobDir/<safeFilename>.jpg` fetched via `Data(contentsOf: artURL)`
      if `artworkUrl` starts with http (atomic write).
  11. Finalize to `musicDir/<safeFilename>.<ext>`, `.lrc`, `.jpg`:
      remove existing final audio, `moveItem` audio, move artwork if staged.
      Errors → cleanup + finish fail `"Failed to save audio file"`. Then `cleanupJobDir`.
  12. Non-blocking LRC: `LyricsManager.shared.fetchRawSyncedLRC(artist:title:) { lrc in ... }`
      → on `DispatchQueue.global(qos: .utility)` remove existing + write lrc atomically.
  13. `LocalLibraryManager.shared.scanLibrary { _ in ... }` → if videoId:
      `LocalLibraryManager.shared.assignYTVideoID(vid, toFileAt: finalAudioURL.path)`;
      `finishTask(task, success:true, "✓ Downloaded <title>", resultDetail: "Saved to ~/Music/Mooziac")`.
- **Errors**: catch → cleanup + null activeProcess + finish fail `"Error: <localizedDescription>"`.
- **Async**: runs on `workQueue`; UI mutations on main; LRC write on global utility.

#### `handleStreamingProgress(taskID:videoId:title:progress:eta:speed:)` (565-589)
- **Purpose**: coalesced progress broadcast.
- **Called by**: pipe `readabilityHandler` (background thread).
- **Coalescing**: min 0.08s between notifications OR `progress >= 0.99`; AND `delta >=
  0.02` OR `>= 0.99` OR first broadcast. Updates `lastProgressNotificationTime`/
  `lastBroadcastProgress` **without a lock** (data race — see RISKS). Dispatches main:
  set currentProgress/ETA/speed, broadcast `.downloading`, broadcast queue status.

#### `finishTask(task:success:message:resultDetail:)` (592-630)
- **Purpose**: single finalization path for success/failure/cancel.
- **Idempotency guard**: under `queueLock`, bail if `activeTask?.id != task.id`.
- On main: broadcast `.completed(1.0)` or `.failed(message)` (progress 0.0 for fail);
  `task.completion?(success, resultDetail ?? message)`; under lock set `activeTask = nil`;
  if queue empty → `isDownloading=false`, `onDownloadStatusChanged?(false, "")`;
  `broadcastQueueStatus()`; `processNextQueueTask()`.
- **Called by**: many paths above + `cancelTask`/`cancelAllDownloads`.

#### `broadcastProgress(id:videoId:title:progress:eta:speed:status:)` (633-660)
- **Purpose**: fire `onProgressUpdated` + post `"Mooziac_DownloadProgress"` notification.
  userInfo keys: `id`, `title`, `progress`, `eta`, `speed`, `status` (stringified),
  optional `videoId`.

#### `broadcastQueueStatus()` (662-692)
- **Purpose**: post `"Mooziac_DownloadQueueChanged"`. Computes `remaining`, `total`
  (from `totalBatchCount`), `index`; builds `displayText`
  `"Downloading <i>/<total>: <title> (<pct>%• ETA <eta>)"` (or single-item form).
  userInfo keys: `activeTitle`, `progress`, `eta`, `speed`, `remaining`, `total`,
  `index`, `displayText`.

#### `makeProcessEnvironment()` (static, 695-723)
- **Purpose**: PATH augmentation for spawned processes. Prepends standard candidate dirs
  (home `~/.local/bin`, `~/.pyenv/shims`, `/opt/homebrew/bin`, `/opt/homebrew/sbin`,
  `/usr/local/bin`, `/usr/local/sbin`, `~/.cargo/bin`,
  `/Library/Frameworks/Python.framework/Versions/Current/bin`, `/usr/bin`, `/bin`,
  `/usr/sbin`, `/sbin`) deduped before existing PATH segments. Sets
  `PYTHONUNBUFFERED=1`.

#### `runShellPathResolution(_ cmd:)` (static, 725-747)
- **Purpose**: run `zsh -l -c <cmd>`, take first non-empty line, verify
  `isExecutableFile` + exit 0 → return path.
- **Errors**: swallowed (`catch {}`), returns nil.

#### `resolveYtDlpPath()` (749-779)
- **Purpose**: cached lookup; then login-shell `command -v yt-dlp || which yt-dlp ||
  command -v youtube-dl || which youtube-dl`; then direct candidate paths
  (`~/.local/bin/yt-dlp`, `~/.pyenv/shims/yt-dlp`, `/opt/homebrew/bin/yt-dlp`,
  `/opt/homebrew/sbin/yt-dlp`, `/usr/local/bin/yt-dlp`, `~/.cargo/bin/yt-dlp`,
  `/usr/bin/yt-dlp`, `/opt/homebrew/bin/youtube-dl`, `/usr/local/bin/youtube-dl`).
- **Output**: `String?`; caches in `ytDlpPath`.

#### `resolveFFmpegLocation()` (781-796)
- **Purpose**: login-shell `command -v ffmpeg || which ffmpeg` → dirname, else candidate
  dirs (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, `/usr/bin`) with
  executable `ffmpeg`. Returns directory path for `--ffmpeg-location`.

#### `extractErrorMessage(from lines:)` (static, 798-829)
- **Purpose**: map yt-dlp output to a friendly error.
- Filters out `WARNING:`, `[youtube] WARNING`, `Deprecated Feature`. Keeps lines with
  `ERROR:`, `[youtube] ERROR`, or `ffmpeg is not installed`. Takes last; strips
  `ERROR:` prefix; special-cases `403: Forbidden` → `"Access forbidden (403). yt-dlp
  update recommended."`, `Requested format is not available` → `"Audio format
  unavailable for this track."`, `Sign in to confirm`/`bot` → `"YouTube bot check
  triggered. Try again later."`, `ffmpeg` → `"FFmpeg missing. Install via: brew install
  ffmpeg"`, else truncate to 60 chars with `...`.

#### `cancelQueuedTask(id:)` (832-840)
- **Purpose**: mark cancelled + remove from queue; broadcast queue status on main.
  Does NOT touch an active process.

#### `cancelTask(id:)` (842-874)
- **Purpose**: cancel queued or active task. If removed from queue → broadcast, return.
  If active: insert into `cancelledTaskIDs`, `process.terminate()`, schedule SIGKILL
  after 2s, then on main `finishTask(active, success:false, message:"Download cancelled")`.
- **Note**: `finishTask` is guarded by active id, so a re-finalization by the unwinding
  worker is ignored.

#### `cancelAllDownloads()` (876-908)
- **Purpose**: cancel everything: mark all ids cancelled, clear queue, terminate process
  (SIGKILL fallback 2s), finish active with `"Download cancelled"` on main (or broadcast
  queue status if none).

#### `parseYtDlpProgress(line:)` (static, 911-939)
- **Purpose**: parse a `[download] ... N% ...` progress line.
- Requires `[download]` + `%`. Percent via regex `(\d+(?:\.\d+)?)%` clamped to 0...1.
  ETA via regex `ETA\s+(\S+)`, strips `ETA`, converts `00:MM:SS` → `"Ns"`. Speed via
  regex `at\s+(\S+/s)`, strips `at`.

#### `validateJobAudioFile(in jobDir:)` (942-975)
- **Purpose**: pick a valid audio file from the sandbox.
- Lists dir (`.skipsHiddenFiles`), filters `supportedAudioExts`, requires regular file,
  size > 10240, duration > 1.0 (AVURLAsset), `asset.isPlayable`. Returns first match.
  Called from executeDownloadTask; **on the workQueue**.

#### `cleanupJobDir(_:)` (978-985)
- **Purpose**: clear `currentActiveJobDirURL` if matching, `removeItem` (try?).

#### `extractVideoID(from:)` (static, 988-1012)
- **Purpose**: return 11-char bare id, or regex-extract from:
  `[?&]v=([A-Za-z0-9_-]{11})`, `youtu\.be/([A-Za-z0-9_-]{11})`,
  `music\.youtube\.com/(?:playlist|watch|embed)/([A-Za-z0-9_-]{11})`,
  `youtube\.com/embed/([A-Za-z0-9_-]{11})`.

---

## Cross-file wiring summary

- **Data flow**: FS (LLM) → SQLite cache (LDM `tracks`) → in-memory `_allTracks` →
  `PlaylistLibraryIndex` (PM) → resolve local/online → playback (NativeAudioPlayer /
  NowPlayingManager) or downloads (DM) → back to FS + `assignYTVideoID`.
- **Notifications**: `"Mooziac_LibraryUpdated"` (LLM→PM/views), `"Mooziac_DownloadProgress"`
  (DM), `"Mooziac_DownloadQueueChanged"` (DM).
- **UserDefaults keys written by these files**: `"YTM_downloadsFolder"` (LLM),
  `"Mooziac_SQLite_Liked_Migration_V1_Done"` (LDM), `"Mooziac_OfflineLikedKeys"` (read),
  `"Mooziac_CleanedPresetPlaylists_v1"` (PM).
  Keys read: `"YTM_lastTitle"`, `"YTM_lastArtist"`, `"YTM_lastVideoId"`,
  `"YTM_lastArtwork"` (PM; written by ObserverBridge).
- **Queues**: `com.mooziac.localdatabase` (serial, history ops only),
  `com.mooziac.locallibrary` (serial, scans/import/delete),
  `com.mooziac.downloader.work` (serial, downloads), `com.mooziac.downloader.timeout`
  (serial, utility, timeouts). Plus `DispatchQueue.global(qos:.utility)` (LRC writes),
  `DispatchQueue.global()` (kill fallbacks), `DispatchQueue.main` (UI).

---

## RISKS & OBSERVATIONS

### Concurrency / thread-safety
1. **`LDM` transaction groups not atomic under a queue.** `BEGIN TRANSACTION`/`COMMIT`
   in `upsertTracks`, `deleteTracks`, `replacePlaylistItems`, `reorderPlaylistItems`
   rely on FULLMUTEX serialized mode; interleaving with other threads' statements is
   prevented by SQLite, but a partially-executed batch followed by an exception path
   (e.g. `sqlite3_prepare` failure) can leave an open transaction. `sqlite3_exec` steps
   are unchecked for errors.
2. **`recordHistoryItem` vs synchronous readers.** `recordHistoryItem` runs on
   `dbQueue.async`; `fetchHistory`/`fetchHistoryCount`/`deleteHistoryItem`/`clearHistory`
   use `dbQueue.sync` — consistent. But **all other** LDM APIs (fetchAllRecords,
   upsertTracks, playlist CRUD, liked songs) run on the caller's thread with no queue
   coordination; only SQLITE_OPEN_FULLMUTEX saves them. Mixed prepared-statement use
   across threads is allowed by sqlite3 in serialized mode but the code assumes it.
3. **`DM.handleStreamingProgress` data race.** `lastProgressNotificationTime` and
   `lastBroadcastProgress` are mutated from the `Pipe.readabilityHandler` thread (line
   444+) without a lock and read from the same thread; `finishTask`/`executeDownloadTask`
   reset them on main/worker. True data race (Swift memory-model), benign in practice.
4. **`DM` active-process bookkeeping.** `activeProcess` is written under `queueLock`
   (433-435) but read without lock in `handleTaskTimeout` (339) and `cancelTask` (849).
5. **`PM.activeContext` unsynchronized.** `public private(set) var activeContext` is
   mutated from `removeItem`, `reorderItems`, `playNext`, `startPlaylist`,
   `playNextTrackInPlaylist`, `playPreviousTrackInPlaylist`, `clearActiveContext` on
   whatever thread calls them (assumed main in practice). No lock. If any caller invokes
   from a background queue, torn state is possible.
6. **`LLM` scan completion deadlock potential.** `scanLibrary` fires `completionsToFire`
   on main; a completion that calls `scanLibrary` from main while a scan is running will
   be moved to `pendingCompletions` and run by a follow-up scan — correct, but if a
   completion blocks the main thread waiting on `queue` (e.g. an LDM `dbQueue.sync`
   inside a scan completion) a stall is possible. LDM history `sync` calls are the
   dangerous pairing.
7. **`process.waitUntilExit()` blocks `workQueue`.** Serial queue means no other download
   can start while one runs — intended serial behavior — but `handleTaskTimeout`'s SIGKILL
   escalation on `DispatchQueue.global` races `waitUntilExit` unwinding.

### Data integrity / error handling
8. **`executeRaw` failures ignored in migrations.** A failed DDL batch leaves
   `user_version` unchanged so it retries next launch — good — but `sqlite3_exec` step
   results in `upsertTracks`/`deleteTracks`/`replacePlaylistItems` are not checked;
   silently dropped rows.
9. **`fetchAllRecords`/`fetchHistory` use `String(cString:)` on possibly NULL columns** —
   guarded for lrc/yt columns in fetchAllRecords (455-461), and history uses `.map` for
   nullable columns — but `sourceType` in fetchHistory falls back to `"online"` if NULL,
   masking schema drift.
10. **`LDM.recoverCorruptDatabase` runs on main thread at startup** and deletes the whole
    DB; `try? removeItem` swallows failures. If the app crashes during rebuild, WAL
    replay may leave a partially rebuilt DB.
11. **`LLM.extractMetadata` has no AVAsset error handling.** `AVURLAsset` duration/common
    metadata on corrupt files can throw/return garbage; only NaN/Infinite are guarded.
    Files that fail to load metadata silently get duration 0 / filename title.
12. **`LLM` stale-track deletion could delete records for still-mounting volumes**
    (e.g. cloud-synced Music folder) — any transient unavailability of the file becomes
    a DB deletion, and the next scan re-upserts it (self-healing but churny).

### Dead code / duplication
13. **`LDM.currentSchemaVersion = 3` is never read** (grep-verified) while the real
    schema is at v4 — misleading constant.
14. **`LDM.filePaths(byVideoID:)` has no callers** (grep-verified) — dead.
15. **`PM.currentNowPlayingVideoID`, `PM.localTracks(in:)`,
    `PM.appendCurrentTrack(to:)`, `PM.clearActiveContext()` have no callers**
    (grep-verified) — dead.
16. **`PM.metaFor`/`iconAndColorFor` ignore the playlist-name argument** and return the
    same hardcoded cyan icon/color for every playlist.
17. **`LDM.fetchHistory` + `fetchHistoryCount` duplicate the dedup CASE expression** —
    any change must be made in both places.
18. **`DM` library dedup logic differs between `queueTrack` and `queueTracks`**:
    single uses clean-title+artist wildcard; batch uses signature set. Inconsistent
    duplicate handling across the two entry points.
19. **`LLM.toggleLike` + `LocalTrack.isLiked` setter both call into LDM** — calling
    `toggleLike` on an already-liked track flips it off; the setter guards against
    redundant writes (LocalTrack.swift:31-33) but `toggleLike` itself doesn't.

### Fragile state / lifecycle
20. **`DM.cancelTask`/`cancelAllDownloads` then `finishTask(... message:"Download
    cancelled")`** — the worker thread (still in `waitUntilExit`) may simultaneously hit
    the cancel branch (terminationStatus 15/-15) and return without calling `finishTask`;
    the idempotency guard in `finishTask` protects double-finalization, but the 
    "cancelled" branch at line 478-481 cleans the job dir and returns without firing the
    task's `completion` callback or advancing the queue. If `process.terminate()` makes
    the exit status 15, the callback never fires. **Potential missed-completion bug.**
21. **`DM.totalBatchCount` only grows** (`max(...)`) and is only reset when the queue
    drains; a task queued while another batch is mid-flight corrupts `total` display.
22. **`DM.cleanupStaleDownloads` runs at init before any job dir exists** — fine — but it
    compares `dir != currentActiveJobDirURL` where `currentActiveJobDirURL` is nil at
    that time; any pre-existing dirs are removed (intended).
23. **`PM.playOnlineVideo` hardcodes URL `list=RDAMVM<vid>`** — radio-queue hack; if YTM
    changes the URL shape it silently falls to JS path first (JS is attempted first).
24. **`PM.playTrackAtCurrentContextIndex` for `.unavailable` recurses into
    `playNextTrackInPlaylist`** which can recurse again → unbounded recursion if many
    consecutive unavailable items (stack growth; end-of-playlist path clears context and
    returns false, so bounded by playlist length but deep).

### Security / secrets
25. **JS injection surfaces:** `PM.addToQueue` interpolates `videoId` into a JS string,
    and `PM.playOnlineVideo` interpolates into `loadVideoById('...')`. The video ids are
    derived from DB/UserDefaults; a malicious id with `'` could break out of the string.
    Low practical risk (id is 11-char alnum regex-validated in DM, but PM does not
    re-validate).
26. **No secrets in source.** yt-dlp is invoked with user-supplied URLs/titles only; no
    API keys, tokens, or cookies are embedded. yt-dlp's own config/cookies are outside
    this module.
27. **`Data(contentsOf: artworkUrl)`** in `DM.executeDownloadTask` is a synchronous
    network fetch on the workQueue with no timeout — a hung artwork host stalls the
    download queue (blocking `waitUntilExit` of the *next* task only after current
    completes; actually it blocks the current finalization path).

### Performance / UX
28. **`HistoryRecord.relativePlayedTimeString`** allocates a `DateFormatter` per call —
    minor; on long history lists (200 rows) this is 200 formatter allocations.
29. **`LLM.scanLibrary` fires every completion with the same full `[LocalTrack]`**
    array — views receive large copies frequently.
30. **`LDM` FULLMUTEX + per-call `sqlite3_prepare`** — no prepared-statement reuse across
    calls; every public API prepares on demand. Fine at this scale, but the batched
    write paths re-prepare per invocation.
31. **`DM` progress broadcast is duplicated** — `broadcastProgress` posts the
    notification AND `handleStreamingProgress` calls `broadcastQueueStatus()`; plus
    `finishTask` broadcasts progress + queue status + `onDownloadStatusChanged`. Multiple
    UI refreshes per event; coalesced at 8/s so acceptable.

### Schema / migration
32. **`v1` DDL already defines `yt_video_id`**, yet `migrateToV2` re-checks/ALTERs it.
    Comment acknowledges it's idempotent; the ALTER is a no-op on fresh installs, but the
    `idx_tracks_yt_video_id` CREATE INDEX is duplicated (in v1 block and migrateToV2) —
    `IF NOT EXISTS` makes it harmless.
33. **No `updated_at` trigger on `playlist_items`** — `updated_at` of playlists is
    maintained only via explicit `touchPlaylist` calls scattered through item mutations;
    any missed call leaves stale sort order in the `fetchPlaylists` ORDER BY.
34. **`deleteTracks` cascades only `ref_type = 'local'`** — `yt` items referencing a
    deleted video's `yt_video_id` are not cleaned, and `ON DELETE CASCADE` applies only
    to playlists, not tracks → orphaned `yt` rows with dangling refs are possible.

---

## COUNTS

- **Files analyzed**: 4
- **Classes/structs/enums defined** (in the 4 files):
  - Classes: `LocalDatabaseManager`, `LocalLibraryManager`, `PlaylistManager`,
    `DownloadManager` = **4**
  - Structs: `CachedTrackRecord`, `PlaylistRecord`, `PlaylistItemRecord`, `HistoryRecord`,
    `PlaylistLibraryIndex`, `DownloadProgressInfo`, `QueueTask` (nested), `PlaylistItemSource`
    (enum), `PlaylistPlayResult`, `PlaylistDownloadPlan`, `ActivePlaylistPlaybackContext`,
    `DownloadStatus` (enum) = **12**
- **Functions/methods documented**: 
  - LDM: 40 (incl. init/deinit/computed accessors & all 34 public APIs + 8 private helpers)
  - LLM: 18
  - PM: 44 (incl. nested types' helpers, static funcs, computed accessors)
  - DM: 29
  - Total ≈ **131**
- **DB tables**: 5 — `tracks`, `playlists`, `playlist_items`, `listening_history`,
  `liked_songs`
- **SQL statements documented**: **41** (5 DDL table defs + 9 index defs + 4 PRAGMAs +
  2 transaction ctrl + 21 DML/select/upsert statements across the API surface)
- **Notification names**: 3 — `"Mooziac_LibraryUpdated"`,
  `"Mooziac_DownloadProgress"`, `"Mooziac_DownloadQueueChanged"`
- **File paths used**: 
  - `~/Library/Application Support/Mooziac/library.sqlite3` (+ `-wal`, `-shm`)
  - `~/Library/Application Support/Mooziac/Offline/`
  - `~/Music/Mooziac/` (default) / custom `YTM_downloadsFolder`
  - `~/Music/Mooziac/.downloading/<jobId>/`
  - `~/Library/Caches/Mooziac/Thumbnails/` (artwork cache, via AppArtworkHelper)
- **UserDefaults keys**: 5 written/read in these files (`YTM_downloadsFolder`,
  `Mooziac_SQLite_Liked_Migration_V1_Done`, `Mooziac_OfflineLikedKeys`,
  `Mooziac_CleanedPresetPlaylists_v1`, + reads of `YTM_last{Title,Artist,VideoId,Artwork}`)
- **Risks found**: **34** documented observations (see RISKS & OBSERVATIONS above;
  includes 5 concurrency items, 5 dead-code items, 3 security/JS-injection items, and
  others).