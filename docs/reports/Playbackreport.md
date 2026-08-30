# Mooziac — Playlist, Download & Offline Architecture Report

**Deliverable:** `/Playbackreport.md`
**Scope:** Read-only audit of the playlist, download, and offline/online playback architecture of the Mooziac macOS menu-bar app (Swift Package, `Sources/Mooziac`).
**Constraint honored:** No source code was modified, refactored, renamed, or deleted. No dependencies, configs, or data were changed. All findings below are evidence-based from source inspection.

---

## 1. Executive Summary

Mooziac is a menu-bar music player that embeds YouTube Music in a `WKWebView` for online playback and uses a native `AVPlayer` (`NativeAudioPlayer`) plus a locally-stored media library for offline playback. The two engines are bridged by a single central state hub, `NowPlayingManager`, whose `engineMode` (`.online` / `.offline`) selects the active engine.

The architecture is reasonable for a solo project: a single SQLite store, a filesystem-scanned library, a serial download worker over `yt-dlp`, and notification-driven UI. However, the audit found **two critical defects**, one high-impact race, and a cluster of medium/low issues:

1. **CRITICAL — Download queue deadlocks permanently after a yt-dlp timeout.** `DownloadManager.swift:478-481` treats exit status `15` (the SIGTERM sent by the timeout handler) as a cancelled/aborted path and returns **without calling `finishTask`**, so `activeTask` is never cleared and `processNextQueueTask` can never start another download.
2. **CRITICAL — "Player forgets to switch back to online mode."** `NowPlayingManager.setupNetworkObserver` (`NowPlayingManager.swift:97-108`) handles only the *offline* transition. Nothing observes `NetworkMonitor.reconnectedNotification` to flip `engineMode` back to `.online`; only `YTMWebView` reloads on reconnect. Because `PlayerControls` gates on `engineMode == .offline || !isReachable`, the player can remain stuck on the offline engine indefinitely.
3. **HIGH — Duplicate download race.** Queue dedup is by task `id` (UUID), not by `videoId`, so the same video can be queued twice from two playlist items / two rapid taps, causing a second redundant `yt-dlp` run and a same-name file overwrite.

Medium/low issues include: no AVPlayer failure observers, online "liked" state reset at every launch, `PlaybackState.engineMode` never assigned (dead field), `PlaylistManager.play/shufflePlay` returning hard-coded zero counts, `playNext` no-op for online items, no download queue persistence/resume, O(n) `allTracks` copies, and untrimmed caches.

**Bottom line:** Ship-blocking fixes are small and localized (2–3 functions). The playlist/persistence layer is the strongest area; the download worker and the online/offline transition are the weakest.

---

## 2. Scope & Methodology

### In scope
- Playlist system (SQLite model, index, resolution, playback wiring).
- Download system (`yt-dlp` worker, queue, progress, completion, timeout, cleanup).
- Offline/online engine-mode selection and network-state handling.
- Local library scan/index, metadata, dedup.
- Storage layer, caches, session state, startup/restore.
- Threading model, race conditions, failure modes, performance, security, code quality.

### Out of scope
- WebView rendering behavior of YTM itself, yt-dlp extraction correctness, Discord RPC protocol details, gesture mapping internals, theme/visual design.

### Method
- Full read of ~20 source files under `Sources/Mooziac` (core managers read end-to-end).
- Cross-reference greps: `engineMode`, download state enums, notification names, `UserDefaults` keys, remote-command hooks, playlist playback call sites.
- Evidence format used throughout: `Location: <file>`, `Component: <type>`, `Function: <method>`.
- Where a claim could not be fully verified statically it is marked **needs verification**.

### Files inspected (primary)
| File | Lines | Role |
|---|---|---|
| `NowPlayingManager.swift` | ~298 | Central state hub, `engineMode`, network observer |
| `NowPlayingManager/PlayerControls.swift` | ~120 | Play/pause/next/prev engine dispatch |
| `NowPlayingManager/ObserverBridge.swift` | ~400 | JS↔Swift bridge, mutual exclusivity, session keys |
| `NowPlayingManager/Queue.swift` | ~230 | YTM DOM queue scraping |
| `NativeAudioPlayer.swift` | ~439 | AVPlayer offline engine |
| `DownloadManager.swift` | ~1013 | yt-dlp queue worker |
| `LocalLibraryManager.swift` | ~467 | Filesystem scan, index, dedup, ytVideoId assignment |
| `LocalDatabaseManager.swift` | ~802 | SQLite schema + CRUD |
| `PlaylistManager.swift` | ~765 | Playlist CRUD, resolution, playback context |
| `NetworkMonitor.swift` | ~90 | NWPathMonitor wrapper |
| `YTMWebView.swift` | ~490 | Web container, crash recovery, cache |
| `AppArtworkHelper.swift`, `LyricsManager.swift`, `TrackNotificationManager.swift`, `AppDelegate.swift`, `MainViewController.swift`, `PlaylistLibraryView.swift`, `OfflineLibraryView.swift`, `DynamicIslandPlayerView/*`, `LocalTrack.swift`, `CircularProgressDownloadButton.swift`, `StatusItemManager.swift`, `BackgroundMediaController.swift`, `AudioRouteMonitor.swift`, `KeyboardCommandHandler.swift` | | UI + support |

---

## 3. System Overview & Architecture

```
                       ┌─────────────────────────────────────────────────────┐
                       │  NowPlayingManager (singleton)                      │
                       │  currentState: PlaybackState                       │
                       │  engineMode: .online | .offline  ◄── selection bit  │
                       │  observers[]: (PlaybackState)->Void                │
                       └──────────────┬──────────────────────────────────────┘
                 .online              │ engine dispatch           .offline
                 ┌────────────────────┴──────────────┐
                 ▼                                  ▼
   ┌──────────────────────────┐      ┌──────────────────────────────┐
   │ YTMWebView (WKWebView)   │      │ NativeAudioPlayer (AVPlayer) │
   │  - YouTube Music page    │      │  - plays files from library │
   │  - ObserverBridge (JS)   │      │  - queue / shuffle / repeat  │
   │  - URLCache 512KB/2MB    │      └──────────────┬───────────────┘
   └────────────┬─────────────┘                     │
                │                    ┌──────────────┴───────────────┐
                │                    │ LocalLibraryManager          │
                │                    │  - scan ~/Music/Mooziac      │
                │                    │  - _allTracks (stateLock)    │
                │                    └──────────────┬───────────────┘
                ▼                                   ▼
   ┌──────────────────────────┐      ┌──────────────────────────────┐
   │ DownloadManager          │      │ LocalDatabaseManager (SQLite)│
   │  - yt-dlp queue worker   │      │  tracks / playlists / items  │
   │  - sandbox job dirs      │      └──────────────────────────────┘
   └────────────┬─────────────┘                 ▲
                ▼                               │
   ┌──────────────────────────┐      ┌──────────┴───────────┐
   │ ~/Music/Mooziac/*.m4a    │      │ PlaylistManager       │
   │ ~/Music/Mooziac/.downloading/ │  │  - resolution         │
   └──────────────────────────┘      │  - activeContext queue │
                                     └──────────────────────┘
```

Supporting singletons: `NetworkMonitor` (connectivity), `AppArtworkHelper` (artwork caches), `LyricsManager` (LRC cache + fetch), `TrackNotificationManager` (change notifications), `DiscordRPCManager`, `BackgroundMediaController` (sleep prevention), `AudioRouteMonitor` (device/screen events), `StatusItemManager` (menu bar).

### Key data flow (happy path)
1. User plays a playlist item → `PlaylistManager.startPlaylist` builds `activeContext` (items + local queue + index).
2. `playTrackAtCurrentContextIndex` resolves the item via `resolve()`:
   - `.local` → `NowPlayingManager.playOfflineTrack` → `NativeAudioPlayer.play` (engine `.offline`).
   - `.online` → `switchToOnlineMode` + JS `loadVideoById` in the webview (engine `.online`).
   - `.unavailable` → no-op.
3. Engine broadcasts into `NowPlayingManager.currentState`; observers (UI, Discord RPC, notifications, lock-screen) react.

---

## 4. Component Inventory

| Component | Type | Responsibility | Weakness |
|---|---|---|---|
| `NowPlayingManager` | Singleton | State hub; `engineMode`; network observer; liked-set | Reconnect not handled; liked set reset at init |
| `NativeAudioPlayer` | Singleton | AVPlayer engine; queue/shuffle/repeat | No failure observers; broadcast gated on `.offline` |
| `PlayerControls` | Static funcs | Play/pause/next/prev engine dispatch | Gates on `engineMode == .offline \|\| !isReachable` |
| `ObserverBridge` | NSObject | JS messages; mutual exclusivity; session UserDefaults | Stale-flip heuristics |
| `YTMWebView` | NSView | Web container; crash recovery; cache | Only reconnect observer is here (reload) |
| `PlaylistManager` | Singleton | Playlist CRUD; index; resolution; playback context | Misleading counts; online `playNext` no-op |
| `DownloadManager` | Singleton | yt-dlp queue worker | Timeout deadlock; no resume; dedup by id |
| `LocalLibraryManager` | Singleton | Scan/index/dedup/assign ytVideoId | O(n) `allTracks` copies; full re-scan |
| `LocalDatabaseManager` | Singleton | SQLite schema + CRUD | No WAL verification; full reload per scan |
| `NetworkMonitor` | Singleton | NWPathMonitor; status/reconnected notifications | Reconnect signal under-observed |
| `AppArtworkHelper` | Singleton | Memory + disk thumbnails | Network failure → placeholder; no stale cleanup |
| `LyricsManager` | Singleton | LRC fetch/cache | Request-id juggling; no cache size limit |
| `TrackNotificationManager` | Singleton | Change notifications | Temp artwork cleanup on each track |

---

## 5. Data Model & Storage Layer

### SQLite (`LocalDatabaseManager`)
- **Location:** `LocalDatabaseManager.swift` (schema ~202-291)
- **Component:** `LocalDatabaseManager`
- **Function:** `setupDatabase`, `createTables`
- DB path: `~/Library/Application Support/Mooziac/library.sqlite3`. `import SQLite3` (SDK-provided module; no SPM dependency).

Schema (user_version 2):

```
tracks (filePath TEXT PRIMARY KEY, videoId TEXT, title TEXT, artist TEXT,
        album TEXT, duration REAL, artworkLocalPath TEXT, addedAt REAL,
        liked INTEGER, playCount INTEGER, lastPlayedAt REAL)

playlists (id TEXT PRIMARY KEY, name TEXT, createdAt REAL, updatedAt REAL,
           sortOrder INTEGER, colorHex TEXT, isPreset INTEGER)

playlist_items (id TEXT PRIMARY KEY, playlistId TEXT, sortOrder INTEGER,
                refType TEXT,          -- 'local' | 'yt'
                refId TEXT,            -- local: file path ; yt: video URL/id
                title TEXT, artist TEXT, artworkUrl TEXT, duration TEXT,
                ytVideoId TEXT, isLiked INTEGER)
```

- All writes go through a single serial `dbQueue`; parameter binding is used consistently (no SQL injection via values observed).
- **Findings:**
  - `tracks.filePath` doubles as the primary key **and** the unique local track identity used across the system (e.g., `PlaylistLibraryIndex.byFilePath`, `OfflineLibraryView`, `NativeAudioPlayer`). Renaming/moving a file externally invalidates the id.
  - `playlist_items` stores a **denormalized snapshot** (`title`, `artist`, `artworkUrl`, `duration`, `isLiked`) at add-time; if local file metadata changes later, the playlist row is never refreshed (stale UI until re-add).
  - `ytVideoId` is duplicated on `tracks` and `playlist_items`; assignment path for local downloads is `LocalLibraryManager.assignYTVideoID` → DB + in-memory (verified), but **playlist items are not back-filled** when a downloaded track later receives a `videoId` — resolution covers this via `byVideoId`, so it is functional but leaves two sources of truth.
  - `deleteTracks` also deletes `playlist_items` whose `refType='local'` reference the deleted path (`LocalDatabaseManager` delete path, needs verification of exact line) — this is the intended cascade.

### Filesystem
- Music folder: `~/Music/Mooziac` (`LocalLibraryManager.musicFolderURL`).
- Legacy import folder: `~/Library/Application Support/Mooziac/Offline` (`appSupportOfflineURL`) — **never written to by the download system**; downloads land in the music folder.
- Download sandbox: `~/Music/Mooziac/.downloading/{jobId}/` (isolated per-task dir; cleaned on completion/failure/cancel).
- Thumbnails: `~/Library/Caches/Mooziac/Thumbnails` (disk cache for artwork).
- Lyrics: `~/Library/Caches/Mooziac/Lyrics` (LRC cache).

---

## 6. Playlist System — Data Flow

### Creation / add
- **Location:** `PlaylistManager.swift`
- **Component:** `PlaylistManager`
- **Functions:** `createPlaylist`, `appendCurrentPlayingTrack`, `appendLocalTracks`, `addToQueue`, `reorderItems`, `removeItem`, `replacePlaylistItems`, `deletePlaylist`
- New playlists get a UUID `id`; items get UUID `id` + `sortOrder` (insertion order; reorder rewrites the full list in one transaction).
- `appendCurrentPlayingTrack` de-dupes by `ytVideoId` for online items and by `refType=='local' && refId==path` for local items.

### Index & resolution
- **Location:** `PlaylistManager.swift`
- **Component:** `PlaylistManager`
- **Functions:** `libraryIndex()`, `resolve(item:in:)`, `summaryForPlaylist`
- `PlaylistLibraryIndex` caches three dicts (`byFilePath`, `byId`, `byVideoId`) built from `LocalLibraryManager.shared.allTracks` under `indexLock`; invalidated on `Mooziac_LibraryUpdated` (observed at line 87).
- `resolve()` returns `.local` (downloaded/imported copy found), `.online` (reachable + has ytVideoId/url), or `.unavailable` (offline, no local copy).
- `summaryForPlaylist` caches per-playlist summary until library invalidation.

### Playback wiring
- **Location:** `PlaylistManager.swift` + `MainViewController.swift` + `PlaylistLibraryView.swift`
- **Component:** `PlaylistManager`, `MainViewController`, `PlaylistLibraryView`
- **Functions:** `play(item:in:completion:)`, `startPlaylist`, `playTrackAtCurrentContextIndex`, `handlePlaySingleItem`, `playPlaylist(playlistID:startingAt:)`
- Double-click / row action in `PlaylistLibraryView` (line ~679 `playPlaylist(playlistID:startingAt:)`, invoked at 604/619/806/926) → `startPlaylist` → plays the item under the cursor.
- `MainViewController.playlistLibraryDidPlayOnline` → `switchToOnlineMode()` then JS `loadVideoById` (online path).

---

## 7. Playlist System — State Machines

### Playlist playback context (`PlaylistManager.activeContext`)
```
States: idle → building (startPlaylist) → playing → track-advanced | item-removed | item-reordered → playing | idle
Transitions:
  startPlaylist(items, startID)      : idle → playing
  playTrackAtCurrentContextIndex()   : playing → playing (next/prev), currentIndex moved
  removeItem(itemID)                 : playing → playing (queue & localQueue rebuilt, index re-mapped by id)
  reorderItems(newOrder)             : playing → playing (order rewritten)
  videoEnded / playerEnded           : playing → playing (advance) or idle (queue empty → stop)
Terminal: queue exhausted → stop (no wrap-back unless repeat).
```
- **Not persisted:** `activeContext` (playlist, local queue, index) is in-memory only. On app quit, playback position in a playlist is lost.

### Item resolution state
```
item (refType local | yt)
   │
   ├─ byFilePath hit (local copy)        ──► .local
   ├─ byVideoId hit (downloaded copy)    ──► .local
   ├─ reachable && ytVideoId present     ──► .online
   └─ otherwise                          ──► .unavailable
```
`.unavailable` items are skipped silently by `playTrackAtCurrentContextIndex` (no UI surfacing).

---

## 8. Download System — Data Flow

### Queue & enqueue
- **Location:** `DownloadManager.swift`
- **Component:** `DownloadManager`
- **Functions:** `queueTrack(...)`, `queueTracks(...)`, `processNextQueueTask`
- `QueueTask { id, videoId, title, artist, artworkUrl, duration, priority, isFromBatch, batchTitle }`.
- Queue is **in-memory only** (`tasksQueue` + `activeTask`), guarded by `queueLock`; single serial worker (`workQueue`) processes one task at a time (`maxConcurrency = 1`).
- `queueTrack` de-dupes against the existing library (by videoId / title+artist signature) and against already-queued tasks **by task id (UUID) only** — not by `videoId` (see Section 16, race R3).

### Worker lifecycle (`executeDownloadTask`)
```
enqueue → processNextQueueTask (serial workQueue)
  → resolveYtDlpPath() (yt-dlp must exist; else fail "brew install yt-dlp ffmpeg")
  → build targetQuery (URL | watch URL | ytsearch1:"A - T")
  → create sandbox dir ~/Music/Mooziac/.downloading/{jobId}
  → Process yt-dlp -x --audio-format m4a --audio-quality 0
      --embed-thumbnail --embed-metadata --ffmpeg-location <path>
  → readabilityHandler parses \r\n progress lines → handleStreamingProgress (coalesced)
  → waitUntilExit()
  → if cancelled/SIGTERM   : cleanupJobDir + return          [BUG: no finishTask]
  → if exit != 0           : cleanupJobDir + finishTask(fail)
  → validateJobAudioFile (AVURLAsset) : fail if invalid
  → stage artwork (try? write jpg)
  → move file to ~/Music/Mooziac/<Artist - Title>.m4a (removeItem existing + moveItem)
  → assignYTVideoID (DB + in-memory) → scanLibrary
  → finishTask(success) → broadcast → processNextQueueTask
```

### Progress & notifications
- `DownloadStatus` enum: `queued | downloading(progress, eta, speed) | completed | failed(String)`.
- Notifications: `Mooziac_DownloadProgress`, `Mooziac_DownloadQueueChanged`.
- UI state via `CircularProgressDownloadButton.State` (`idleDownload | queued | downloading | completed | unavailable`), mapped from `DownloadManager.statusFor(id:videoId:)` (line 107).

### Cancellation
- `cancelTask`/`cancelAllTasks` add ids to `cancelledTaskIDs`; the running process is killed (SIGTERM then SIGKILL after 3s). The queue worker observes `isCancelled` after exit and skips `finishTask`.

---

## 9. Download System — State Machines

```
task: queued ──► downloading ──► completed
                 │   │
                 │   ├─ timeout (SIGTERM, status 15) ──► [cleanup + return]  ◄── CRITICAL: activeTask never cleared → queue deadlocked
                 │   ├─ cancelled (SIGKILL/SIGTERM)    ──► [cleanup + return]
                 │   └─ failure (exit != 0)            ──► failed(String)
```
**Critical finding (confirmed):** `DownloadManager.swift:478-481`

```swift
if isCancelled || process.terminationStatus == 15 || process.terminationStatus == -15 {
    cleanupJobDir(jobDir)
    return          // ← finishTask is NOT called
}
```

On timeout, `handleTaskTimeout` (`DownloadManager.swift:336-351`) sends SIGTERM. The worker wakes from `waitUntilExit`, `isCancelled` is **false** (the id was never added to `cancelledTaskIDs`, and `activeTask?.id == task.id` still holds), but `terminationStatus == 15` makes the branch true. It cleans the job dir and returns **without `finishTask`**, so:
- `activeTask` stays set forever,
- `totalBatchCount` / `currentItemCountInBatch` never reset,
- `processNextQueueTask` guard (`guard activeTask == nil`) can never pass → **every subsequent download silently refuses to start.**

Any single hung yt-dlp (captcha, bad network, stalled extractor) that hits `downloadTimeout` bricks the download feature until relaunch. A pre-existing `.downloading` dir is also cleaned at launch (`cleanupStaleDownloads`), so the relaunch recovers — masking the defect.

---

## 10. Offline Mode — Data Flow

### Trigger
- `NetworkMonitor.statusChangedNotification` posts on any path change.
- `NowPlayingManager.setupNetworkObserver` (`NowPlayingManager.swift:97-108`) on `!isReachable`:
  1. `engineMode = .offline`
  2. If no local track is current and library non-empty → `NativeAudioPlayer.primeLastOrFirstTrack()`.

### Local playback
- `NativeAudioPlayer.play(track:in:queue:)` → AVPlayer, broadcasts via `broadcastPlaybackState`.
- **Gating:** `NativeAudioPlayer.broadcastPlaybackState` starts with `guard NowPlayingManager.shared.engineMode == .offline else { return }` (line ~405). While `engineMode == .online`, local playback state is **not** broadcast to observers (UI, Discord, notifications). This is intentional (only one engine owns the UI) but means a stale `.online` while a local track is actually playing produces a frozen UI.

### Recovery path (the reported bug)
- On reconnect, `NetworkMonitor` posts `reconnectedNotification`.
- **Only `YTMWebView` observes it** (reload the web page; restores last video/paused). `NowPlayingManager` has **no** observer.
- `switchToOnlineMode()` (`NowPlayingManager.swift:81-87`) — the only routine that flips `.offline → .online` with an `EngineModeChanged` post — is called **only from explicit user actions** (`playOnlineVideo`, `MainViewController.playlistLibraryDidPlayOnline`, `dynamicIslandDidSearch`) and from `ObserverBridge` mutual exclusivity (line ~346-351) when the webview starts real playback while offline.
- Therefore after a reconnect the player **stays on the offline engine** with the local track, exactly matching the report "player forgets to switch back to online mode."

### Manual escape hatches (why it sometimes "fixes itself")
- User clicks a playlist online item / searches → `switchToOnlineMode`.
- WebKit autoplays (e.g., the reloaded watch page starts the next YTM track) → `ObserverBridge` flips to `.online` and pauses the offline player.
- If neither happens, the app remains offline indefinitely even though the network is back.

---

## 11. Offline Mode — State Machines

### Engine mode machine
```
                 NetworkMonitor offline (isReachable==false)
        ┌───────────────────────────────────────────────────────────────┐
        ▼                                                               │
  ┌──────────┐   playOfflineTrack / NativeAudioPlayer.play* /         │
  │  OFFLINE │◄──── PlayerControls offline gate                        │
  └────┬─────┘                                                         │
       │  switchToOnlineMode()            (explicit user action)       │
       │  ObserverBridge (WebKit playing)                              │
       ▼                                                               │
  ┌──────────┐─────────────────────────────────────────────────────────┘
  │  ONLINE  │
  └──────────┘
```
**Missing transition (confirmed):** `NetworkMonitor.reconnectedNotification → engineMode = .online`. No code path flips the mode on reconnect.

### Reconnect handling today
| Observer | Action on reconnect |
|---|---|
| `YTMWebView` (line ~116-121) | Reload webview (restore last video, paused) |
| `DynamicIslandPlayerView` / `HeaderView` | UI toast only |
| `NowPlayingManager` | **none** |
| `NativeAudioPlayer` | **none** (continues local track) |

---

## 12. Connectivity & Network State Management

- **Location:** `NetworkMonitor.swift`
- **Component:** `NetworkMonitor`
- **Functions:** `startMonitoring`, `pathUpdateHandler`, `statusChangedNotification`, `reconnectedNotification`
- `isReachable` defaults `true` at init; the first `NWPathMonitor` callback corrects it shortly after launch (small window where engine defaults to `.online` even when offline).
- Notifications are posted on the main queue via `didSet`.
- Consumers: `YTMWebView` (reload), `DynamicIslandPlayerView.networkStatusChanged` (toast), `HeaderView`, `LyricsManager` (re-fetch guard), `DownloadManager` (dedup reachability), `LocalLibraryManager` (prime), `NowPlayingManager` (offline switch only).
- `isSystemSleeping` (screen lock / system sleep) suppresses `evaluateJS` calls app-wide (`NowPlayingManager.evaluateJS`).

---

## 13. Playback Integration (Online/Offline Engine Selection)

### Dispatch logic (`PlayerControls.swift`)
- **Component:** `PlayerControls`
- **Functions:** `togglePlayPause`, `play`, `pause`, `nextTrack`, `previousTrack`

```swift
// togglePlayPause (line ~23)
if engineMode == .offline || !NetworkMonitor.shared.isReachable {
    if engineMode != .offline { engineMode = .offline }
    ... NativeAudioPlayer.shared.togglePlayPause()
    return
}
// else: WebKit JS evaluate pause/play
```

- **Consequence:** the gate is *sticky in the offline direction*. Once `engineMode == .offline`, even with the network restored and `isReachable == true`, the first condition short-circuits and **every** play/pause goes to the offline engine. The user cannot "tap out" of offline mode without an explicit online action (search / online playlist item).

### Mutual exclusivity (`ObserverBridge`)
- **Location:** `NowPlayingManager/ObserverBridge.swift` (~345-356)
- When `engineMode == .offline` but the webview reports real playback (`isPlaying && !title.isEmpty`), the bridge pauses the offline player, flips `engineMode = .online`, and posts `Mooziac_EngineModeChanged`.
- **Weakness:** relies on WebKit actually emitting playback; if the reloaded page stays paused (the normal restore state is paused), the flip never fires.

### Playlist-driven dispatch (`PlaylistManager`)
- `playTrackAtCurrentContextIndex` routes `.local → playOfflineTrack`, `.online → playOnlineVideo` (switchToOnlineMode + JS). `.unavailable` → skipped silently.

---

## 14. Online Queue Integration

- **Location:** `NowPlayingManager/Queue.swift`
- **Component:** `QueueScraper` / DOM extraction
- Extracts YTM's "Up Next" queue by scraping DOM/JS; supports building a snapshot used for playlist save (`saveQueueAsPlaylist` path in `PlaylistManager`).
- **Limitations:**
  - Depends on YTM DOM structure (brittle; `needs verification` against current YTM layout).
  - Queue is not persisted; on relaunch the online queue is whatever YTM restores.
  - `PlaylistManager.playNext` / `addToQueue` for `.online` items: `case .online: break` (`PlaylistManager.swift` ~394-428) — inserting into `activeContext` but **no actual playback or queue insertion** is performed. "Play Next" is effectively a no-op for online items.

---

## 15. Threading & Concurrency Model

| Queue / context | Owned by | Work |
|---|---|---|
| Main queue | UI, `NowPlayingManager`, `PlaylistManager.activeContext`, `NativeAudioPlayer` commands (via `DispatchQueue.main` in `PlaylistManager`) | playback dispatch, JS calls, observers |
| `workQueue` (serial) | `DownloadManager` | yt-dlp execution, queue stepping, progress parsing |
| `timeoutQueue` (serial) | `DownloadManager` | per-task timeouts |
| `dbQueue` (serial) | `LocalDatabaseManager` | all SQLite |
| background queue + `stateLock` | `LocalLibraryManager` | scan, index, dedup, `assignYTVideoID` |
| `ioQueue` (concurrent) + `ioGroup` | `AppArtworkHelper` | thumbnail load/store |
| main (via NWPathMonitor) | `NetworkMonitor` | path updates |
| `UserDefaults` | all | session state |

- **Rule of thumb observed:** every cross-thread handoff is funneled to main before touching shared singletons; the three serial queues isolate downloads, DB, and library scanning from each other. This is the strongest part of the design.
- `ObserverBridge` JS messages arrive on main; `WKScriptMessageHandler` conformance keeps state mutations main-bound.

---

## 16. Race Conditions & Thread-Safety

### R1 — (CONFIRMED, CRITICAL) Download timeout → queue deadlock
- **Location:** `DownloadManager.swift:478-481`
- **Component:** `DownloadManager`
- **Function:** `executeDownloadTask`
- Timeout branch returns without `finishTask`; `activeTask` never cleared; queue permanently stalled. See Section 9.

### R2 — (CONFIRMED, CRITICAL) Stuck offline mode after reconnect
- **Location:** `NowPlayingManager.swift:97-108`
- **Component:** `NowPlayingManager`
- **Function:** `setupNetworkObserver`
- Only the offline transition is handled; reconnect never flips `engineMode`. Combined with the sticky gate in `PlayerControls.togglePlayPause`, the offline engine stays selected. See Sections 11–13.

### R3 — (CONFIRMED, HIGH) Duplicate download of the same video
- **Location:** `DownloadManager.swift` (`queueTrack` / `queueTracks`)
- **Component:** `DownloadManager`
- **Function:** `queueTrack`
- Library dedup is checked at enqueue time only. Two items sharing a `videoId` (e.g., same song in two playlists, or rapid "download current" taps) produce two `QueueTask`s (distinct UUIDs). Both are accepted because queue dedup compares task `id`, not `videoId`. The second `yt-dlp` run redundantly downloads and **overwrites** the first task's final file (same `<Artist - Title>.m4a`), with a remove-then-move window.
- The library dedup for the second task runs *after* the first completes; if the first is still in flight, the second's enqueue-time check sees no library hit.

### R4 — (MEDIUM) Scan vs. download-completion mutation
- `LocalLibraryManager` scan runs on background; `assignYTVideoID` mutates `_allTracks[i]` under `stateLock`. Snapshot copies handed to callers are safe (structs), but a caller holding a pre-download snapshot will briefly resolve the item as `.online`/`.unavailable` until the next `Mooziac_LibraryUpdated` invalidation rebuilds `PlaylistLibraryIndex`. Bounded, self-healing on the next scan/UI refresh.

### R5 — (LOW) Startup window of wrong engine
- `isReachable` defaults `true`; before the first NWPathMonitor callback, an actually-offline machine briefly keeps `engineMode == .online`. `PlayerControls` may attempt a JS call that fails. Self-corrects when the offline status arrives.

### R6 — (LOW) `summaryForPlaylist` cache
- Cached until library update; a playlist edited by another path (e.g., `replacePlaylistItems`) invalidates only via the library-update notification. `refreshPlaylistsSection` triggers summary rebuilds. Acceptable.

### Thread-safety verdict
- Shared mutable state is mostly main-bound or lock/queue-guarded. The three confirmed defects are **logic/state-machine bugs**, not classic data races. No `NSLock` misuse observed in download/DB/library layers; `queueLock`/`stateLock`/`indexLock` are held briefly and consistently.

---

## 17. Error Handling & Failure Modes

| Failure | Handling | Gap |
|---|---|---|
| yt-dlp missing | Clean fail message ("brew install yt-dlp ffmpeg") | None |
| yt-dlp exit != 0 | `finishTask(fail)` + stderr tail logged | Good |
| yt-dlp timeout | SIGTERM → SIGKILL; cleanup; **return without finishTask** | **Queue deadlock** (R1) |
| Corrupt audio file | `AVURLAsset` validation, fail | Good (but only at download-time) |
| Local file corrupt at playback | — | **No `AVPlayerItem` failure observers** (`failedToPlayToEndTime`, `playbackStalled` not observed); corrupt file silently stalls with a paused-looking UI |
| Network drop mid-online | engine → `.offline`, prime last/first track | Good (intent); flip-back missing (R2) |
| Web content crash | `YTMWebView` crash-recovery state machine + offline overlay retry | Depends on reload; no engine fallback |
| Playlist item unavailable | `resolve()` → `.unavailable`, skipped | No user feedback when skipped |
| Downloaded file overwritten (name collision) | remove + move | Silent data loss window (R3) |
| Lyrics fetch failure | OVH fallback + cache | Good |
| Artwork fetch failure | Memory→disk→network→placeholder JPEG | Offline shows last cached thumb; placeholder otherwise |

---

## 18. Performance Analysis

| Concern | Evidence | Assessment |
|---|---|---|
| `LocalLibraryManager.allTracks` returns a full copy of the array on **every call** | getter (`LocalLibraryManager.swift` ~12-16) | O(n) per call, called from search, dedup, queue, resolution, UI refresh. At 10k+ tracks, copies on every keystroke / refresh add churn. **Medium** |
| Full re-scan | `enumerateFilesystemTracks` re-enumerates + stats all files; `fetchAllRecords` loads every row each scan | Acceptable for typical libraries; scales poorly. **Low-Medium** |
| `resolve()` per table row | O(1) via cached `PlaylistLibraryIndex` | Good |
| Summary per playlist | Cached in `summaryCache` | Good |
| Playback time callbacks | NativeAudioPlayer 0.25s periodic + YTM `timeupdate` ~1s → `notifyObservers` (incl. Discord RPC key check) ~4×/sec | Fine for a menu-bar app; watch if Discord presence becomes hot |
| Artwork | NSCache (500 items / 50MB) + disk thumbnails; async `ioQueue` | Good |
| `progressNotification` during downloads | coalesced (`lastBroadcastProgress` threshold, 1s min interval) | Good |
| Lyrics | request-id guarded; cached on disk | Good |

---

## 19. Caching & Storage Behavior

| Cache | Location | Limits | Cleanup |
|---|---|---|---|
| `URLCache.shared` | `YTMWebView` init (512KB memory / 2MB disk) | Very small | Automatic |
| Artwork memory | `AppArtworkHelper.memoryCache` NSCache 500 / 50MB | Bounded | Automatic |
| Artwork disk | `~/Library/Caches/Mooziac/Thumbnails` | **Unbounded** | Only deleted when the owning track is deleted via the app; external deletions leave orphans |
| Lyrics | `~/Library/Caches/Mooziac/Lyrics` | **Unbounded** | None |
| Downloaded audio | `~/Music/Mooziac/*.m4a` (de-facto offline cache) | Unbounded | Only via user delete |
| Download index | SQLite `tracks` table | — | — |
| `UserDefaults` | session keys (below) | — | Key purge in `NowPlayingManager.init` |

### Session state (`UserDefaults`)
- Written by `ObserverBridge`: `YTM_lastVideoId`, `YTM_lastTime` (throttled 5s), `YTM_lastUrl`, `YTM_lastTitle`, `YTM_lastArtist`, `YTM_lastArtwork`, `YTM_lastIsLiked`, plus `YTM_likedTrackKeysSet` (online liked set).
- **Issue (confirmed):** `NowPlayingManager.init` (`NowPlayingManager.swift:89-92`) **removes `YTM_likedTrackKeysSet` and `YTM_lastIsLiked` at every launch** — online "liked" state is reset on restart. `isTrackLiked/setTrackLiked/trackKey` (lines 173-191) then operate on an empty set. The heart button can persist during a session but not across launches.
- Restored at startup by `YTMWebView` (last video/time) and `DynamicIslandPlayerView.restoreSavedState` (title/artist/artwork/liked).
- `LocalLibraryManager` persists per-track `liked` locally (DB) — local likes are durable; only **online** likes are reset.

---

## 20. Security Considerations

| Item | Assessment |
|---|---|
| SQL injection | Mitigated — values use `sqlite3_bind_*`; identifiers are constants. **Low risk** |
| JS injection into `evaluateJavaScript` | **Medium risk (needs verification for all sites)** — several paths interpolate `videoId`/`refId`/titles from DB into JS strings (e.g., `loadVideoById`, `playOnlineVideo`). A corrupted/malicious playlist row (or YTM-surfaced metadata) containing quotes/backticks could break out of the string. Recommend `JSONSerialization`-encoding all interpolated values. |
| Filename sanitization | Only `/` and `:` replaced (`DownloadManager.swift:390-392`). macOS tolerant, but control characters / path-length / traversal edge cases are unsanitized. **Low-Medium** |
| No secrets in code | No API keys; uses public YTM web + yt-dlp. **Good** |
| `Process` environment | `makeProcessEnvironment()` sets `HOME`/`PATH` for yt-dlp; `--no-update`, pinned player clients. **Good** |
| Remove-then-move file writes | Not atomic as a pair; a crash between them loses the previous file. **Low** |

---

## 21. Data Integrity & Persistence

- All DB writes are serialized on `dbQueue`; playlist reorders and batch replaces are transactional.
- **Strengths:** primary keys are stable (`filePath`, UUIDs); cascade delete of playlist items on track delete; `Mooziac_LibraryUpdated` keeps UI/index in sync.
- **Weaknesses:**
  - `activeContext` (playlist playback position) is not persisted → position lost on quit.
  - Download queue is not persisted → pending downloads lost on quit (no resume, no retry/backoff).
  - Playlist item metadata snapshots go stale if local metadata changes.
  - Two sources of truth for `ytVideoId` (tracks vs playlist_items) — no back-fill to playlist_items after assignment.
  - `PlaybackState.engineMode` (field in `PlaybackState`, default `.online`) is **never assigned anywhere** — dead/misleading property (`NowPlayingManager.swift:39`).

---

## 22. Startup, Restore & Session State

Startup order (`AppDelegate.applicationDidFinishLaunching`):
1. Purge legacy UserDefaults keys (v1/v2).
2. `BackgroundMediaController` (sleep prevention), `EdgeVolumeEngine`, `AudioRouteMonitor`, `NetworkMonitor.startMonitoring`, `DiscordRPCManager`, `StatusItemManager` (creates `MainViewController`).
3. `MainViewController` builds views → `DynamicIslandPlayerView.restoreSavedState` (title/artist/artwork), `OfflineLibraryView` (triggers `LocalLibraryManager` scan), `PlaylistLibraryView` (playlists), `YTMWebView` (restores last video/time, paused).
4. If offline during scan and no current track → `primeLastOrFirstTrack`.

Restore gaps:
- `engineMode` defaults `.online`; first NWPathMonitor callback corrects if actually offline (small transient window — R5).
- Local playback position is not restored (no `lastPlayedAt` seek restore).
- Online queue not restored; liked set reset (Section 19).
- `.downloading` sandboxes from a killed run are cleaned at launch, but a **still-running orphaned yt-dlp** from a force-quit is not killed (`needs verification` — no `applicationWillTerminate`/process reaping observed).

---

## 23. UI Integration Points

| UI | Wired to | Notes |
|---|---|---|
| `DynamicIslandPlayerView` | `NowPlayingManager` observers, `NetworkMonitor.statusChangedNotification` toast, `YTM_playerDesignChanged` | `networkStatusChanged` toast (line ~792-799) is the only UI feedback on reconnect |
| `PlaylistLibraryView` | `PlaylistManager`, `startPlaylist`, reorder drag (`dragType`), play/delete | Row double-click and context actions call `playPlaylist(startingAt:)` |
| `SettingsPanel` (`DetailItemRowView`) | `PlaylistManager` CRUD; download buttons `handleDownloadDetailItem → queueTrack` (line ~750-791); `statusFor` → `CircularProgressDownloadButton.State` | Download-all / per-row download; state re-driven on `Mooziac_DownloadQueueChanged`/`_Progress` |
| `OfflineLibraryView` | `LocalLibraryManager`, `DownloadManager` download/import buttons, search, refresh on `Mooziac_LibraryUpdated` | `handleDownloadCurrentTapped` appears **unused** (no button invokes it) — `needs verification` |
| `MainViewController` | Mode flags (`isBrowserMode` / `isOfflineLibraryMode` / `isPlaylistLibraryMode`), `playlistLibraryDidPlayOnline` | Online playlist play routes through `switchToOnlineMode` + JS |
| `HeaderView` | Network status icon/label | Mirrors `isReachable` |
| `CircularProgressDownloadButton` | `State` enum (5 states) | Clean mapping; `unavailable` shown when offline/unreachable |

---

## 24. Code Quality & Maintainability

- **Strengths:** consistent notification-name constants; clear singleton layout; serial worker isolation; enum-driven states; decent print/logging on failures; coalesced progress; request-id staleness guards in `LyricsManager`.
- **Weaknesses:**
  - `PlaylistManager` mixes DB I/O, resolution, and playback context in one ~765-line type (single-responsibility stretch).
  - `DownloadManager` is ~1013 lines with inline `Process` orchestration and stringly-typed progress parsing.
  - Several dead/near-dead symbols: `PlaylistManager.metaFor` / `iconAndColorFor` (return constants), `PlaylistManager.play/shufflePlay` counts (hard-coded zeros at return), `PlaybackState.engineMode` (never set), `BackgroundMediaController` unused audio node props, `OfflineLibraryView.handleDownloadCurrentTapped` (unwired).
  - No test target in `Package.swift`; state machines (especially engine mode) are untested — directly contributed to the two critical bugs.
  - Mild stringly-typed keys (`"Mooziac_LibraryUpdated"`, `"YTM_lastTitle"`) — central notification constants exist for downloads but many others are literal.

---

## 25. Findings Summary & Evidence

| ID | Severity | Finding | Location / Component / Function | Section |
|---|---|---|---|---|
| F1 | **CRITICAL** | Download timeout leaves `activeTask` set; queue deadlocks | `DownloadManager.swift:478-481` / `DownloadManager` / `executeDownloadTask` | 9, 16 |
| F2 | **CRITICAL** | No reconnect handler flips `engineMode` back to `.online`; player sticks offline | `NowPlayingManager.swift:97-108` / `NowPlayingManager` / `setupNetworkObserver` | 11, 12, 16 |
| F3 | HIGH | Play/pause gate `engineMode == .offline \|\| !isReachable` is sticky in the offline direction | `NowPlayingManager/PlayerControls.swift:23+` / `PlayerControls` / `togglePlayPause` | 13 |
| F4 | HIGH | Duplicate downloads of same `videoId` (dedup by task id, not videoId); remove-then-move overwrite | `DownloadManager.swift` / `DownloadManager` / `queueTrack`, `executeDownloadTask` | 16 |
| F5 | MEDIUM | No AVPlayer failure observers; corrupt local file stalls silently | `NativeAudioPlayer.swift` / `NativeAudioPlayer` / `play(track:)` | 17 |
| F6 | MEDIUM | Online liked set + `YTM_lastIsLiked` removed at launch | `NowPlayingManager.swift:89-92` / `NowPlayingManager` / `init` | 19 |
| F7 | MEDIUM | `PlaylistManager.play/shufflePlay` return hard-coded zero counts (misleading) | `PlaylistManager.swift` / `PlaylistManager` / `play`, `shufflePlay` | 7 |
| F8 | MEDIUM | `playNext`/`addToQueue` no-op for `.online` items | `PlaylistManager.swift:394-428` / `PlaylistManager` / `playNext`, `addToQueue` | 14 |
| F9 | MEDIUM | `PlaybackState.engineMode` never assigned | `NowPlayingManager.swift:39` / `PlaybackState` | 21 |
| F10 | LOW-MED | `allTracks` full-array copy per call | `LocalLibraryManager.swift:12-16` / `LocalLibraryManager` / `allTracks` | 18 |
| F11 | LOW-MED | JS string interpolation of DB values (injection surface) | `YTMWebView` / `NowPlayingManager.evaluateJS` call sites | 20 |
| F12 | LOW | No download resume/queue persistence; pending downloads lost on quit | `DownloadManager` / `tasksQueue` | 21 |
| F13 | LOW | `activeContext` playlist position not persisted | `PlaylistManager` / `activeContext` | 7, 21 |
| F14 | LOW | Thumbnail/lyrics caches unbounded; orphaned by external deletion | `AppArtworkHelper`, `LyricsManager` | 19 |
| F15 | LOW | Startup engine window before first NWPathMonitor callback (`isReachable` defaults true) | `NetworkMonitor.swift:22+` | 12, 16 |
| F16 | LOW | Dead code: `metaFor`, `iconAndColorFor`, `handleDownloadCurrentTapped`, unused audio nodes | `PlaylistManager`, `OfflineLibraryView`, `BackgroundMediaController` | 24 |
| F17 | LOW | Playlist item metadata snapshots not refreshed on local metadata change | `LocalDatabaseManager` / `playlist_items` | 5, 21 |
| F18 | LOW | Orphaned yt-dlp on force-quit not reaped; `.downloading` cleanup at launch only | `DownloadManager` / `cleanupStaleDownloads` | 22 |

---

## 26. Prioritized Fix Recommendations & Roadmap

| Priority | Finding | Recommended fix | Location / Component / Function | Effort |
|---|---|---|---|---|
| **P0** | F1 | Call `finishTask(task:success:message:)` on the SIGTERM/timeout path instead of bare `return`, or route timeout into the `cancelledTaskIDs` set **before** the worker wakes (set id in `handleTaskTimeout`). Add a regression test that enqueues a hung URL and asserts the next task still runs. | `DownloadManager.swift:478-481` / `DownloadManager` / `executeDownloadTask`, `handleTaskTimeout` | S |
| **P0** | F2+F3 | Add a `reconnectedNotification` observer in `NowPlayingManager` that flips `engineMode = .online`, pauses the offline engine, posts `Mooziac_EngineModeChanged`, and (optionally) re-issues the last online playback command via `YTMWebView`. Make `PlayerControls` decide by **actual source** (is the current/queued track local vs online) rather than `engineMode` alone, so the gate isn't sticky. | `NowPlayingManager.swift:97-108` / `NowPlayingManager` / `setupNetworkObserver` + `PlayerControls.togglePlayPause` | S–M |
| **P1** | F4 | Dedup queue by `videoId` (and title+artist signature) across `tasksQueue` + `activeTask`; after completion, re-check library before writing final file; write final file atomically (temp + rename). | `DownloadManager.queueTrack` / `queueTracks` / finalize step | M |
| **P1** | F5 | Observe `AVPlayerItem.failedToPlayToEndTime`, `.playbackStalled`, and `.didPlayToEndTime`; on failure advance to next track or surface error state. | `NativeAudioPlayer.play(track:)` | S |
| **P1** | F7/F8 | Either implement `playNext` for online items (queue via YTM) or remove the misleading zero-count returns in `play`/`shufflePlay`. | `PlaylistManager.play`, `shufflePlay`, `playNext` | S–M |
| **P2** | F6 | Persist the online liked set (e.g., store to DB or a non-purged key; stop removing at init) or wire it through `LocalDatabaseManager`. | `NowPlayingManager.init` | S |
| **P2** | F10 | Cache a single snapshot + generation counter for `allTracks`, or expose query/index APIs instead of full copies. | `LocalLibraryManager.allTracks` | M |
| **P2** | F11 | JSON-encode every value interpolated into `evaluateJavaScript`. | all `evaluateJS` call sites | S |
| **P2** | F12/F13 | Persist `tasksQueue` and `activeContext` (Codable → DB/UserDefaults) for restart recovery. | `DownloadManager`, `PlaylistManager` | M |
| **P2** | F9 | Set `currentState.engineMode` in `broadcastPlaybackState`/observer posts, or remove the field. | `NowPlayingManager` / `NativeAudioPlayer` | S |
| **P3** | F14 | Add size/age-based eviction to thumbnail + lyrics caches; purge orphaned thumbnail files on library scan. | `AppArtworkHelper`, `LyricsManager` | M |
| **P3** | F15 | Initialize `isReachable` from a synchronous `NWPathMonitor.currentPath` probe at startup. | `NetworkMonitor.startMonitoring` | S |
| **P3** | F16 | Delete or rewire dead symbols. | `PlaylistManager`, `OfflineLibraryView`, `BackgroundMediaController` | S |
| **P3** | F17 | Back-fill/refresh playlist item metadata on library scan completion. | `LocalDatabaseManager` / `PlaylistManager` | M |
| **P3** | F18 | Reap orphaned yt-dlp processes at launch (match by args or PID file); keep `.downloading` cleanup. | `DownloadManager` / `cleanupStaleDownloads` | S |
| **P0-P3** | — | Add a test target (XCTest) with unit tests for: engine-mode transitions (reconnect), download worker timeout/cancel/finish, resolution (local/online/unavailable), dedup. | `Package.swift` / new `Tests/` | M |

**Suggested sequencing:** land P0 fixes (F1, F2/F3) first — both are small and unblock the two most user-visible failures; then P1 correctness items; then P2/P3 hygiene.

---

## 27. Architecture Verdict Ratings & Conclusion

| Area | Rating (/10) | Notes |
|---|---|---|
| Overall architecture | 6.5 | Sound singletons + serial isolation; two critical state-machine gaps |
| Playlist system & persistence | 7.5 | Solid index/resolution/transactions; stale snapshots + no position restore |
| Download system | 5.0 | Good isolation, but timeout deadlock, no resume, dup-download race |
| Offline/online mode | 4.0 | One-directional transition; "forgets to switch back to online" confirmed |
| Concurrency & thread-safety | 6.5 | Queues/locks are clean; defects are logic, not data races |
| Error handling | 4.5 | Great download-fail paths; silent local playback failures; no skip feedback |
| Performance | 6.0 | Cached index good; `allTracks` copies + full re-scan are the main risks |
| Security | 6.5 | Bound SQL good; JS interpolation + filename sanitization need hardening |
| Code quality / maintainability | 6.0 | Clear structure; dead code, stringly keys, big managers, zero tests |
| Testability | 2.0 | No tests; the two critical bugs are exactly what a state-machine test would have caught |

### Conclusion
The playlist and offline-library core is well-architected and mostly safe under concurrency. The system's two worst user-visible behaviors — the download queue silently stopping and the player refusing to return to online mode — are each caused by a single missing/incorrect transition in otherwise simple state machines, and both are fixable in hours with no architectural change. The recommended follow-up is to apply the P0/P1 fixes, add a state-machine test target, and (at P2) reintroduce persistence for the queue and playback position.