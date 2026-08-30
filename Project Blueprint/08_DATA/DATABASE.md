# Database

SQLite backing store for the offline/library features.

## Location & connection

- File: `~/Library/Application Support/Mooziac/library.sqlite3` (+ `-wal`, `-shm`).
- Connection flags: `SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX` (serialized).
- PRAGMAs: `journal_mode = WAL`, `synchronous = NORMAL`, `foreign_keys = ON`, `busy_timeout = 5000`.
- Version tracking: `PRAGMA user_version` = **4**. (`currentSchemaVersion = 3` constant is stale — see risks.)
- Threading: all ops on `dbQueue` (serial, `qos: .userInitiated`).

## Schema (verbatim from source)

### `tracks` (v1)
| Column | Type |
| :--- | :--- |
| id | TEXT PRIMARY KEY |
| file_path | TEXT UNIQUE NOT NULL |
| title | TEXT NOT NULL |
| artist | TEXT NOT NULL |
| album | TEXT NOT NULL |
| duration | REAL NOT NULL |
| date_added | REAL NOT NULL |
| date_modified | REAL NOT NULL |
| file_size | INTEGER NOT NULL |
| is_liked | INTEGER NOT NULL DEFAULT 0 |
| lrc_path | TEXT |
| yt_video_id | TEXT |

Indexes: `idx_tracks_file_path`, `idx_tracks_date_added`, `idx_tracks_yt_video_id`.

### `playlists` (v2)
| Column | Type |
| :--- | :--- |
| id | TEXT PRIMARY KEY |
| name | TEXT NOT NULL |
| created_at | REAL NOT NULL |
| updated_at | REAL NOT NULL |

### `playlist_items` (v2)
| Column | Type |
| :--- | :--- |
| id | TEXT PRIMARY KEY |
| playlist_id | TEXT NOT NULL |
| sort_order | INTEGER NOT NULL |
| ref_type | TEXT NOT NULL |
| ref_id | TEXT NOT NULL |
| yt_video_id | TEXT |
| title | TEXT NOT NULL |
| artist | TEXT NOT NULL DEFAULT '' |
| artwork_url | TEXT NOT NULL DEFAULT '' |
| duration | TEXT NOT NULL DEFAULT '' |
| is_liked | INTEGER NOT NULL DEFAULT 0 |
| date_added | REAL NOT NULL |

`FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE`.
Indexes: `idx_playlist_items_playlist` (playlist_id, sort_order), `idx_playlist_items_yt_video`.

### `listening_history` (v3)
| Column | Type |
| :--- | :--- |
| id | TEXT PRIMARY KEY |
| title | TEXT NOT NULL |
| artist | TEXT NOT NULL DEFAULT '' |
| album | TEXT NOT NULL DEFAULT '' |
| artwork_url | TEXT NOT NULL DEFAULT '' |
| yt_video_id | TEXT |
| file_path | TEXT |
| played_at | REAL NOT NULL |
| duration | REAL NOT NULL DEFAULT 0.0 |
| source_type | TEXT NOT NULL DEFAULT 'online' |

Indexes: `idx_history_played_at` (DESC), `idx_history_video_id`, `idx_history_file_path`.

### `liked_songs` (v4)
| Column | Type |
| :--- | :--- |
| video_id | TEXT PRIMARY KEY |
| title | TEXT NOT NULL |
| artist | TEXT NOT NULL DEFAULT '' |
| album | TEXT NOT NULL DEFAULT '' |
| artwork_url | TEXT NOT NULL DEFAULT '' |
| duration | REAL NOT NULL DEFAULT 0.0 |
| date_liked | REAL NOT NULL |
| synced | INTEGER NOT NULL DEFAULT 0 |
| source_type | TEXT NOT NULL DEFAULT 'ytm' |

Index: `idx_liked_songs_date` (DESC).

## Migrations

`applySchemaIfNeeded()` gates on `user_version`:
- `< 1` → v1 DDL (tracks) → set version 1.
- `< 2` → `migrateToV2()`: `ALTER TABLE tracks ADD COLUMN yt_video_id` if missing (via `columnExists`), + playlists/playlist_items.
- `< 3` → `migrateToV3()`: listening_history.
- `< 4` → `migrateToV4()`: liked_songs.

Each sets `user_version` on success and logs.

## API surface

| Group | Examples |
| :--- | :--- |
| Core | `openDatabase`/`closeDatabase`, `executeRaw`, `prepareStatement`, `columnExists`, `getUserVersion`/`setUserVersion`, `beginTransaction`/`commitTransaction` |
| Tracks | `saveTracks`, `fetchAllTracks`, `updateTrack`, `deleteTrack`, `clearTracks` |
| Playlists | `createPlaylist`, `renamePlaylist`, `deletePlaylist`, `fetchPlaylists`, `insertPlaylistItems`, `updatePlaylistItemSortOrder`, `deletePlaylistItem`, `fetchPlaylistItems` |
| History | `saveHistory`, `fetchHistory`, `deleteHistoryEntry`, `clearHistory` |
| Likes | `saveLikedSong`, `fetchLikedSongs`, `removeLikedSong`, `isSongLiked`, `clearLikedSongs` |

## Corruption recovery

- Open failure → `recoverCorruptDatabase()`: delete DB + WAL/SHM, recreate empty, apply schema, **data loss**.
- If rebuild also fails, `db` stays nil → queries no-op (guarded).
- Writes ignore prepare failures in some paths (see risks).

## Statistics (verified)

- SQL statements documented: **41** (5 table DDL + 9 indexes + 4 PRAGMAs + ~23 DML).
- Writers: LocalLibraryManager, PlaylistManager, HistoryManager, LikedSongsManager, DownloadManager.

## Related

- `08_DATA/STORAGE.md`, `99_APPENDIX/RAW_DISCOVERY_NOTES/03_DATA_MANAGERS.md`.