# Mooziac Playlist System — Architecture Report (Online + Offline, No-Sign-In)

**Status:** IMPLEMENTED (2026-08-16). All eight items below were approved and implemented. Schema migrated to v2 (`PRAGMA user_version = 2`), `QueueItemInfo`/queue JS now capture `videoId`, downloads persist `yt_video_id`, new `PlaylistManager` service + `PlaylistLibraryView` UI added, and the status-bar menu gained "Open Playlists". One deviation from the design: the `playlist_items.ref_id → tracks(file_path)` FK was **dropped** because with `PRAGMA foreign_keys = ON` it rejected `'yt'` items (videoId never matches a file path); local-reference cleanup now happens explicitly in `LocalDatabaseManager.deleteTracks`. Verified: `swift build` passes; SQL migration/CRUD/cascade smoke-tested against a real SQLite file.
**Date:** 2026-08-16
**Scope:** Determine whether the existing Mooziac architecture can support persistent local playlists containing online YT Music tracks, downloaded/local tracks, and mixtures of both — including operation without Mooziac having its own sign-in.

---

## 1. Current Architecture

### 1.1 Online playback

- `YTMWebView.swift` embeds `music.youtube.com` in a `WKWebView` (`YTMWebViewContainer`). Cookies live in `WKWebsiteDataStore.default()` (the user's YT Music browser session).
- Playback is *driven*, never *hosted*, by the app: `NowPlayingManager.evaluateJS(...)` and `PlayerControls.swift` inject JavaScript that calls the `#movie_player` API or simulates clicks on YT Music's buttons (play/pause/next/prev/seek/shuffle/repeat/like/EQ/volume).
- Two mutually-exclusive engine modes exist: `PlaybackEngineMode.online` / `.offline` (`NowPlayingManager.engineMode`). Starting offline audio pauses the WebView and vice-versa (`ObserverBridge.swift` lines ~306–317, `NativeAudioPlayer.playCurrentTrack`).
- Network drops are detected by `NetworkMonitor` (`NWPathMonitor`); on going offline, `engineMode` switches to `.offline` and the local library is primed (`NowPlayingManager.setupNetworkObserver`).
- `YTMWebView` also handles WebContent crash recovery and re-applies the last known video/position.

### 1.2 Offline/local playback

- `LocalLibraryManager` scans two directories: `~/Music/Mooziac` and `~/Library/Application Support/Mooziac/Offline`, extracting metadata via `AVURLAsset`, deduplicating by normalized `title|artist`, and sorting by `dateAdded` descending.
- `NativeAudioPlayer` wraps `AVPlayer`. It already supports playing an **arbitrary** queue: `play(track:in:)`, `nextTrack`/`previousTrack` (with looping), `setShuffleState`, `setRepeatMode` (`.off`/`.one`), end-of-track observer, `handleTrackDeleted`, `seek`, and last-played persistence (`Mooziac_LastPlayedLocalTrackId/Title`).
- `OfflineLibraryView` is a table UI with search/import/open-folder. No playlist UI exists.
- Offline playback is fully sign-in-free: local files + AVPlayer + SQLite + `AppArtworkHelper` (embedded/sidecar art) + `LyricsManager` (sidecar `.lrc`, then LRCLib/lyrics.ovh).

### 1.3 How metadata is currently collected

| Source | Mechanism | Files |
|---|---|---|
| Online now-playing | Injected JS observer (`updateNowPlaying`) posts to `window.webkit.messageHandlers.nowPlayingHandler`; `didReceive` maps into `PlaybackState` | `NowPlayingManager/ObserverBridge.swift`, `NowPlayingManager.swift` |
| Online queue / Up Next | `evaluateJavaScript` DOM scrape of `ytmusic-player-queue-item` nodes, then polymer `queue.items`, then `player.getPlaylist()` | `NowPlayingManager/Queue.swift` |
| Offline local tracks | `FileManager` enumeration + `AVURLAsset.commonMetadata` + sidecar `.lrc`/artwork + SQLite reconciliation | `LocalLibraryManager.swift`, `LocalTrack.swift` |
| SQLite cache | Upsert/delete keyed by `file_path`, reconciliation via `date_modified` + `file_size` | `LocalDatabaseManager.swift` |
| Downloads | `yt-dlp` subprocess (`--embed-metadata --embed-thumbnail`), sidecar LRC/artwork staged then atomically moved | `DownloadManager.swift` |

### 1.4 How queue / Up Next currently works

- `Queue.swift` `fetchQueue()` / `fetchUpNextSnapshot()` return `QueueItemInfo` (index/title/artist/isSelected; UpNext adds artworkUrl, duration-as-string, contextTitle, autoplayEnabled, automixItems).
- Mutations (`playQueueItem`, `removeQueueItem`, `moveQueueItem`, `playNextQueueItem`, `playAutomixItem`, `triggerAutoplayRadio`) simulate clicks / splice the polymer model.
- The queue exists **only inside the YTM WebView DOM**. It is read-only to the app and is not persisted anywhere.

### 1.5 How the core components interact

```
                 WKWebView (music.youtube.com)
                        ▲ online engine / JS bridge
                        │  (click sims / #movie_player API)
        NowPlayingManager ── evaluateJS ──▶ YTMWebView
        │  PlaybackState / observers / engineMode
        ├── ObserverBridge ◀── message bridge (nowPlayingHandler)
        ├── Queue.swift ──── DOM scrape ◀── queue/UpNext
        │
        ▼ offline engine
   NativeAudioPlayer ──AVPlayer──▶ local file
        │  queue = [LocalTrack]
        ▼
   LocalLibraryManager ──scan/reconcile──▶ LocalDatabaseManager (SQLite tracks)
        │  extractMetadata (AVURLAsset)
        ▼
   DownloadManager ──yt-dlp──▶ ~/Music/Mooziac (+ .lrc, artwork) ──▶ library rescan
```

**Key structural fact:** the online path and the offline path share *no data store*. Online is ephemeral WebView state (UserDefaults last-value keys only). Offline is SQLite + files. There is no bridge between `videoId` (online identity) and file path (offline identity).

---

## 2. Current Metadata Inventory

Full machine-readable inventory is in **`trackmetadata.json`** at the repo root. Summary below.

### 2.1 Online now-playing metadata (ObserverBridge → `PlaybackState`)

| Field | Type | Origin | Persisted? |
|---|---|---|---|
| `title` | string | `navigator.mediaSession.metadata.title` \|\| player-bar `.title` | Last-value only (`YTM_lastTitle`) |
| `artist` | string | `mediaSession.metadata.artist` \|\| player-bar `.byline` | Last-value only (`YTM_lastArtist`) |
| `album` | string | `mediaSession.metadata.album` | No |
| `artworkUrl` | string URL | `mediaSession.artwork[last].src` \|\| player-bar `<img>` \|\| `https://i.ytimg.com/vi/{videoId}/hqdefault.jpg` | Last-value only (`YTM_lastArtwork`) |
| `isPlaying` | bool | `video.paused/ended/readyState` | No |
| `currentTime` | double | `video.currentTime` | Last-value only (`YTM_lastTime`, throttled ~5s) |
| `duration` | double | `video.duration` | No |
| `playbackRate` | double | `video.playbackRate` | No |
| `pageUrl` | string URL | `window.location.href` | Last-value only (`YTM_lastUrl`, watch URLs) |
| `videoId` | string (11) | `player.getVideoData().video_id` \|\| URL `?v=` | Last-value only (`YTM_lastVideoId`) — **the online stable identity** |
| `trackID` | string | `videoId` if present else `"{title}_{artist}"` | No (in-memory `currentVideoId`) |
| `isLiked` | bool | `ytmusic-like-button-renderer` like-status / aria-pressed | Last-value (`YTM_lastIsLiked`) + key set `YTM_likedTrackKeysSet` (`VID_`/`TRACK_` keys) |
| `isShuffle` / `isRepeat` | bool | shuffle/repeat buttons | No |

### 2.2 Online queue / Up Next metadata (Queue.swift)

| Field | Type | Origin | Persisted? |
|---|---|---|---|
| `index` | int | DOM position | No |
| `title` | string | `.song-title` / polymer `title.runs[0].text` | No |
| `artist` | string | `.byline` / `longBylineText`/`shortBylineText` | No |
| `isSelected` | bool | `selected` attr / play-button-state | No |
| `artworkUrl` | string URL | thumbnail renderer `img` / `thumbnail.thumbnails[last].url` (UpNext only) | No |
| `duration` | string "m:ss" | duration badge / `lengthText` / `lengthSeconds` (UpNext only) | No |
| `contextTitle` | string | queue header `.metadata .title` (UpNext only) | No |
| `autoplayEnabled` | bool | automix toggle (UpNext only) | No |
| `automixItems` | array | `ytmusic-automix-preview-video-renderer` (UpNext only) | No |

**Missing:** `videoId` on every queue item; source playlist ID/name. Nothing is persisted.

### 2.3 Downloaded / local track metadata (LocalTrack + extractMetadata)

| Field | Type | Origin | Persisted? |
|---|---|---|---|
| `id` | string = **file path** | `fileURL.path` | Yes (SQLite `tracks.id`) |
| `title` | string | `AVURLAsset commonKeyTitle`; fallback filename split on `" - "` | Yes (`tracks.title`) |
| `artist` | string | `commonKeyArtist`; fallback `"Local Audio"` | Yes (`tracks.artist`) |
| `album` | string | `commonKeyAlbumName` | Yes (`tracks.album`) |
| `duration` | double | `AVURLAsset.duration` | Yes (`tracks.duration`) |
| `fileURL` | string path | enumerated file | Yes (`tracks.file_path`, UNIQUE) |
| `artworkURL` | string path \| nil | sidecar `.jpg/.png/.jpeg/.webp` | **No** (recomputed; not in DB) |
| `lrcURL` | string path \| nil | sidecar `.lrc` | Yes (`tracks.lrc_path`) |
| `dateAdded` / `dateModified` | double | file `contentModificationDate` | Yes |
| `fileSize` | int | resource values | Yes (`tracks.file_size`) |
| `isLiked` | bool | SQLite `tracks.is_liked` | Yes |

**Missing:** `ytVideoId`, source URL, and artwork URL are not stored anywhere for local tracks.

### 2.4 SQLite (`tracks` only, schema v1, `~/Library/Application Support/Mooziac/library.sqlite3`, WAL)

Columns: `id` (PK = path), `file_path` (UNIQUE), `title`, `artist`, `album`, `duration`, `date_added`, `date_modified`, `file_size`, `is_liked`, `lrc_path`. **This is the only table.**

### 2.5 Explicit missing-metadata summary

- ❌ `videoId` for online **queue/Up Next** items
- ❌ `yt_video_id` for **downloaded/local** tracks
- ❌ source playlist `browseId`/name of the active queue
- ❌ playlist / playlist-item storage of any kind
- ❌ online track's artwork/duration/album in any durable store (only last-value)

---

## 3. Playlist Architecture Assessment

**Can the current architecture support persistent local playlists containing online + offline + mixed tracks? → NO.**

| Requirement | Current state |
|---|---|
| Playlist persistence | None |
| Playlist table | None (only `tracks`) |
| Playlist-item table | None |
| Ordering / position | None (offline order = dateAdded desc; online = DOM order) |
| Duplicate handling | Offline dedup by `title\|artist` at scan; downloader skips by title/artist match |
| Stable track IDs | Online = `videoId` (current only); Offline = file path. No unified ID |
| Online↔offline association | None |
| Playlist CRUD | None |
| Restore after restart | Only last single track per engine (`YTM_lastVideoId`, `Mooziac_LastPlayedLocalTrackId`) |

What *is* reusable as-is: `NativeAudioPlayer.play(track:in:)` (arbitrary local queue), the SQLite layer (migration-safe), the offline engine (sign-in-free), `LyricsManager`/`AppArtworkHelper` (identity-aware).

---

## 4. No-Sign-In Behavior

| Category | Detail |
|---|---|
| ✅ Works with **no** sign-in (today) | Offline library scan, AVPlayer playback, shuffle/repeat/seek, import/delete, offline liked flag, sidecar `.lrc` + LRCLib/lyrics.ovh lyrics (network but not YT auth), embedded/sidecar artwork. A future **local** playlist system on the existing SQLite also requires no account. |
| 🔑 Requires YT Music session/WebView | Playing online YT Music content, radio/automix, queue/Up Next DOM, online like/repeat/shuffle state, search/home inside the WebView. |
| ❓ Cannot be guaranteed without account | The user's YT Music **library playlists** (`FEmusic_liked_playlists` browse), Liked Songs, add-to-playlist mutations, account-backed mixes. ⚠️ "No sign-in" must **not** be read as anonymous access to YT Music library playlists. |
| 💾 Stored locally regardless of auth | Everything in SQLite + `~/Music/Mooziac` + sidecars. Local playlists are independent of YT Music cloud playlists by design. |
| 📴 Offline behavior | Playlist items resolve to local files → play; online-only items → marked unavailable/skipped (see §7). |
| ⬇️ Online track not downloaded | Played through the YT Music WebView while online; marked unavailable when offline (§7). |

**Design principle:** treat *Mooziac-local playlists* as first-class and independent from *YT Music cloud playlists*. A local playlist can optionally record a source `browseId`/URL, but it never depends on the YT Music account to exist or render.

---

## 5. Identity / Mapping Model (design, not implemented)

Goal: one stable logical identity so an online YT Music track and its downloaded local copy are recognized as the *same* track.

### Identifier roles

| Identifier | Role | Notes |
|---|---|---|
| **YouTube `videoId`** (11-char) | Primary **online** identity | Already the key in `NowPlayingManager.currentVideoId`, `trackKey("VID_"+videoId)`, lyrics cache (`vid_*.lrc`). |
| **Local file path** (`LocalTrack.id` / `tracks.file_path`) | Primary **offline** identity | Unique today; changes on move/rename. |
| **Source URL** | Derived, not canonical | `https://music.youtube.com/watch?v={videoId}` (the code already constructs this in `ObserverBridge`). `pageUrl` is a last-value URL, not a stored field. |
| **Playlist item ID** | Referential identity | `(playlist_id, position)` or a UUID — identifies the *occurrence*, not the track. |

### Proposed mapping

1. Add nullable, indexed **`tracks.yt_video_id`**. A `tracks` row = local file that *knows* its YT Music source (NULL for imported/legacy files).
2. A playlist item carries **`ref_type`** (`'local'` → `tracks.file_path`, or `'yt'` → `videoId`) plus a **denormalized metadata snapshot** (title/artist/album/artwork/duration) so the playlist renders and resolves even when the DB must not be joined.
3. **Resolver:** `videoId → tracks.yt_video_id → LocalTrack` finds the local copy; otherwise the item is online-only.
4. **Duplicate / alternate versions:** a "logical song" may have several `videoId`s (e.g. official vs. remaster). Canonicalize with a **song key** = normalized `title|artist` (the code already has this concept in `LyricsManager.cleanSongInfo`, scan dedup, and downloader duplicate-check). Store the preferred `videoId` on the item; on resolve, prefer a `yt_video_id` match, then a song-key match, then fall back to online-only playback.
5. Lyrics/artwork stay resolved lazily through the existing `LyricsManager` (`"VID:"+videoId` / sidecar path) and `AppArtworkHelper` — no need to duplicate lyrics text in the playlist row; store an optional `lrc_path`/`artwork` reference in the snapshot for offline display.

---

## 6. Persistent Playlist Data Model (proposed SQLite schema)

Fits the existing style (REAL epoch dates, INTEGER flags, WAL, `PRAGMA user_version` migration).

```sql
-- tracks: EXISTING table, ONE added column
ALTER TABLE tracks ADD COLUMN yt_video_id TEXT;           -- NULL for legacy/imported
CREATE INDEX idx_tracks_yt_video_id ON tracks(yt_video_id);

-- playlists: Mooziac-LOCAL playlists (independent of YT Music cloud playlists)
CREATE TABLE IF NOT EXISTS playlists (
    id                 TEXT PRIMARY KEY,                   -- UUID
    name               TEXT NOT NULL,
    description        TEXT,
    is_ytmusic          INTEGER NOT NULL DEFAULT 0,        -- 1 = mirrors/source-linked a YTM playlist (informational)
    source_playlist_id TEXT,                               -- YTM browseId when imported (informational only)
    created_at         REAL NOT NULL,                      -- epoch
    updated_at         REAL NOT NULL
);

-- playlist_items: ordered membership
CREATE TABLE IF NOT EXISTS playlist_items (
    playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    position    INTEGER NOT NULL,                          -- 0-based order
    ref_type    TEXT NOT NULL,                             -- 'local' | 'yt'
    ref_id      TEXT NOT NULL,                             -- tracks.file_path OR videoId
    yt_video_id TEXT,                                      -- normalized link key (may equal ref_id for 'yt')
    song_key    TEXT,                                      -- normalized title|artist (dedup/alternate version)
    title       TEXT NOT NULL,                             -- snapshot
    artist      TEXT,
    album       TEXT,
    duration    REAL,
    artwork_url TEXT,                                      -- online URL or local sidecar path
    lrc_path    TEXT,                                      -- optional lyrics reference
    date_added  REAL NOT NULL,
    PRIMARY KEY (playlist_id, position)
);
CREATE INDEX idx_playlist_items_ref ON playlist_items(ref_type, ref_id);
CREATE INDEX idx_playlist_items_vid ON playlist_items(yt_video_id);
```

**Relationships / keys**

- `playlists.id` (PK, UUID) — playlist identity.
- `playlist_items.playlist_id` → FK → `playlists.id`, `ON DELETE CASCADE`, composite PK `(playlist_id, position)`.
- `playlist_items.ref_id` + `ref_type` → either `tracks.file_path` (local) or a `videoId` (online-only). No FK to `tracks` is enforced because a `'yt'` item has no local row, and local files can be deleted (FK would break the playlist). Resolution is done by `PlaylistManager`, not by the DB.
- `tracks.file_path` stays the unique local identity; `yt_video_id` is the online↔offline link.
- Online track metadata lives **only** in `playlist_items` snapshots (there is no online `tracks` table — online state is ephemeral by design).

---

## 7. Online + Offline Resolution Logic (proposed)

Given a playlist item, resolve to a playable source:

```
Playlist item
   │
   ├─ ref_type = 'local' → local file exists?
   │       YES → play via NativeAudioPlayer (offline engine, no internet needed)
   │       NO  → file deleted → try yt_video_id fallback:
   │               online → play via YT Music
   │               offline → mark unavailable / skip
   │
   └─ ref_type = 'yt' → videoId
           ├─ tracks.yt_video_id match (downloaded copy) → play local file
           │      (optionally promote item to ref_type='local')
           ├─ else online → play through YT Music WebView
           └─ else offline → mark unavailable / skip
```

| Scenario | Behavior |
|---|---|
| Online + local copy exists | Prefer **local file** (instant, saves bandwidth) — configurable; else stream via YT Music. |
| Online + no local copy | Play via YT Music WebView (requires internet + session). |
| Offline + local copy exists | Play via AVPlayer. |
| Offline + no local copy | Mark unavailable, auto-skip (continue to next playable item), show visual "not downloaded" state. |
| Switch online → offline mid-playlist | Continue with next local item; online-only items skipped until reconnected. |
| Switch offline → online | Optionally resume online-only items; keep local items playing locally. |

The `engineMode` switch and `NativeAudioPlayer.play(track:in:)` are already the correct seams — the resolver just feeds the right queue into the right engine, unchanged.

---

## 8. Queue Architecture

**Goal:** convert the temporary YT Music queue into a persistent local playlist/queue without breaking online playback.

1. **Add `videoId` capture** to `fetchQueue()`/`fetchUpNextSnapshot()` (Queue.swift JS reads the queue-item videoId from the DOM/polymer `queue.items`). Existing fields are unchanged — purely additive.
2. **"Save queue as playlist"**: take the `UpNextSnapshot` items (now with videoId) and write them into `playlist_items` via `PlaylistManager.snapshot(...)`. `contextTitle` can seed the playlist name.
3. **Restore queue = play a playlist**: on launch/selection, `PlaylistManager.resolve(playlist)` produces an ordered queue. Local items → `NativeAudioPlayer` queue. Online items → reuse the existing `Queue.swift` click/JS mechanisms (or load `watch?v=videoId`) inside the WebView.
4. **Non-destructive:** the current live YT Music queue keeps working untouched (it is the *runtime* queue). The playlist is a *persistent snapshot* that can be re-loaded into the runtime queue at any time. The existing `fetchQueue`/`playQueueItem`/etc. remain the runtime backend.

---

## 9. Failure Cases

| Case | Today | Proposed behavior |
|---|---|---|
| **File deleted** | `scanLibrary` prunes the row; `handleTrackDeleted` cleans the player queue. | Playlist item becomes dangling: resolver falls back to `yt_video_id` (online) or marks unavailable/skips. |
| **Download moved** | Path-based identity breaks; new path gets a new row (reconcile). | `PlaylistManager` re-links by `yt_video_id` at next scan; snapshot keeps title/artist so the row still renders. |
| **Downloaded after being added to playlist** | n/a (no playlists) | Item was `'yt'`; after download, resolver finds `tracks.yt_video_id` and plays local (optionally upgrades ref). |
| **Removed from downloads** | File deleted from library. | Same as file-deleted fallback (back to online / unavailable). |
| **YT Music metadata unavailable** | Empty title/artist → bridge sends `"Not Playing"`/blanks; queue scrape returns `[]`. | Playlist snapshots already contain denormalized metadata, so the playlist UI/offline stays intact even if live metadata fails. |
| **Duplicate video IDs** | `'yt'` refs with same `videoId` → allow (distinct occurrences) or collapse by item policy. | Configurable per playlist (reject duplicates by `(ref_type, ref_id)`). |
| **Same song, different video IDs** | Downloader skips same title/artist; scan dedups. | `song_key` maps them to one logical track; resolver prefers any matching `yt_video_id`, then song-key fallback. |
| **No internet** | Auto-switch to offline engine; local library primed. | Playlist plays local items; online-only items marked unavailable and skipped. |
| **No sign-in** | Offline path works; YTM WebView works signed-out for public content but no account library. | Local playlists fully work; online items need the WebView/session; account playlists are informational only. |
| **App restart** | Only last video + last local track restored. | Persisted playlists reload from SQLite; optionally restore the last active playlist + position. |

---

## 10. Recommended Architecture

Dual online/offline playlist architecture that **fits the existing player** rather than rewriting it:

```
                ┌──────────────────────────────────────────────┐
                │          PlaylistManager (NEW)               │
                │  CRUD · snapshot-queue · resolve · restore   │
                └──────────┬───────────────────┬───────────────┘
                   ref_type 'local'            ref_type 'yt'
                           │                          │
        NativeAudioPlayer.play(track:in:)    YT Music WebView
        (EXISTING — arbitrary queue)         (EXISTING — Queue.swift
                                              JS bridge / click sims)
                           └──────────┬──────────────────────────┘
                                      ▼
                       NowPlayingManager engineMode switch
                       (EXISTING online/offline arbitration)
```

- **Keep** the existing `WKWebView`, `ObserverBridge`, `Queue.swift`, `NativeAudioPlayer`, `LocalLibraryManager`, `LocalDatabaseManager`, `DownloadManager`, `LyricsManager`, `AppArtworkHelper` exactly as they are.
- **Add** `yt_video_id` capture (online queue + downloaded tracks) and the `playlists`/`playlist_items` tables.
- **Add** a thin `PlaylistManager` singleton (same pattern as `LocalLibraryManager`) that resolves items to either a `LocalTrack` queue or an online playback request.
- Playback of a playlist = build the ordered queue, feed `NativeAudioPlayer.play(track:in:)` for local runs and the WebView for online runs, letting the existing engine arbitration keep them mutually exclusive.

---

## 11. Migration Plan (file by file — NOT to be done now)

| # | File | Change |
|---|---|---|
| 1 | `Sources/Mooziac/NowPlayingManager/Queue.swift` | Add `videoId` to `QueueItemInfo`; extend `fetchQueue`/`fetchUpNextSnapshot` JS to read it (additive). |
| 2 | `Sources/Mooziac/LocalTrack.swift` | Add `public var ytVideoId: String?` (identity, not Equatable-critical). |
| 3 | `Sources/Mooziac/LocalDatabaseManager.swift` | Schema v2 via `PRAGMA user_version`: `ALTER TABLE tracks ADD COLUMN yt_video_id TEXT`; `CREATE TABLE playlists`; `CREATE TABLE playlist_items`; indexes. Add CRUD SQL for playlists/items. |
| 4 | `Sources/Mooziac/LocalLibraryManager.swift` | Read/write `yt_video_id` in `extractMetadata` + `CachedTrackRecord` mapping (reconciliation must preserve it). |
| 5 | `Sources/Mooziac/DownloadManager.swift` | Persist `yt_video_id` at finalize (already receives `urlOrVideoId`); update dedup check to also use `yt_video_id`. |
| 6 | **New** `Sources/Mooziac/PlaylistManager.swift` | CRUD, snapshot-queue-as-playlist, `resolve(item) -> .local/.yt/.unavailable`, restore-on-launch. |
| 7 | **New** `Sources/Mooziac/PlaylistLibraryView.swift` | Playlist list + item table UI (additive; can be gated behind the feature). |
| 8 | `Sources/Mooziac/OfflineLibraryView.swift` | Optional: expose playlists entry point. No behavioral change to existing offline UI. |

No existing table or column is renamed or dropped; no online/offline player behavior is altered.

---

## 12. Final Verdict

**Is the current architecture sufficient for persistent dual online/offline playlists? → NO.**

- **Already reusable (no change needed):**
  - `NativeAudioPlayer.play(track:in:)` — arbitrary offline queue, shuffle/repeat/loop.
  - Offline engine + SQLite layer + sign-in-free local playback.
  - Engine arbitration (`PlaybackEngineMode` online/offline mutual exclusivity).
  - `LyricsManager` (videoId/path keyed) and `AppArtworkHelper` (path keyed).
  - `Queue.swift` runtime queue + click/JS online playback.
- **Missing:**
  - `videoId` on online queue items and on downloaded tracks (`yt_video_id`).
  - `playlists` + `playlist_items` tables and a `PlaylistManager`.
  - Online↔offline resolver and duplicate/alternate-version policy.
  - Playlist restore after restart.
- **Should be added:** the 4 items above (Sections 5–8), additive and non-destructive.
- **Should NOT be rewritten:** the WKWebView/JS bridge, `NativeAudioPlayer`, `LocalLibraryManager`/`LocalDatabaseManager` core, `DownloadManager`, `LyricsManager`, `AppArtworkHelper`, and the existing queue DOM scraping. They all become *consumers* of a new playlist layer.

---

## ⛔ DO NOT IMPLEMENT YET

Before any code changes, the following must be approved:

1. **Scope & identity design** — approve the unified identity model (§5): `yt_video_id` on `tracks`, `song_key` normalization, and the `'local'`/`'yt'` `ref_type` split.
2. **Database schema** — approve the `playlists` / `playlist_items` / `tracks.yt_video_id` schema and migration (v2 via `PRAGMA user_version`) exactly as proposed in §6.
3. **Online queue capture** — approve adding `videoId` to `QueueItemInfo`/`fetchQueue`/`fetchUpNextSnapshot` (additive JS/DOM dependency on YT Music's DOM).
4. **Resolution policy** — approve the online/offline resolution matrix (§7), including "prefer local when online" behavior and skip-on-unavailable semantics.
5. **Duplicate policy** — approve behavior for duplicate video IDs and same-song-different-video (allow/reject; `song_key` fallback).
6. **Queue↔playlist relationship** — approve the "Save queue as playlist" snapshot flow and how restored playlists map back into the runtime queue (§8).
7. **UI scope** — approve whether a `PlaylistLibraryView` is in scope and whether it is additive-only.
8. **No-sign-in contract** — approve that local playlists are Mooziac-local (independent of YT Music cloud playlists), that online items require the WebView/session, and that YT Music library playlists are informational-only without an account.

**✅ Implemented on 2026-08-16** — all items above approved and built:

| # | Item | Implementation |
|---|---|---|
| 1 | Identity model | `tracks.yt_video_id` (schema v2), `ref_type` `'local'`/`'yt'` in `playlist_items` |
| 2 | Schema + migration | v2 via `PRAGMA user_version`; `playlists` + `playlist_items` (denormalized metadata snapshot). FK on `ref_id→tracks(file_path)` dropped (blocked `'yt'` inserts with FK ON); explicit cleanup in `deleteTracks` |
| 3 | Queue videoId capture | `QueueItemInfo.videoId`; `fetchQueue`/`fetchUpNextSnapshot` JS extract from DOM attrs/links, polymer `data.videoId`, and `player.getPlaylist()` |
| 4 | Resolution matrix | `PlaylistManager.resolve(_:)` → `.local(LocalTrack)` / `.online(videoId)` / `.unavailable`; local-first, offline→skip, online-only→watch URL in WebView |
| 5 | Duplicate policy | Skip duplicates on append: same `local` file path or same `yt` videoId |
| 6 | Queue↔playlist | `createPlaylistFromCurrentQueue(name:)` (UpNext snapshot), `appendCurrentTrack(to:)`, restore via `play(playlistID:)` |
| 7 | UI | `PlaylistLibraryView` (list ↔ detail, per-item status, context menus); entry point in status-bar menu; mode handling in `MainViewController` |
| 8 | No-sign-in | Offline playlists fully local/sign-in-free; online items require WebView/session; YTM library playlists not touched |

Deviation note: `playlist_items.ref_id → tracks(file_path)` FK removed (see Status line); local-item cleanup on file deletion is now explicit in `LocalDatabaseManager.deleteTracks`. Everything else follows §5–§8 as proposed.
