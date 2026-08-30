# Next Update: Two-Way Sync with YouTube Music (Liked Songs + Playlists)

**Feature goal:** When the user is signed in to YouTube Music inside the embedded WebView, sync their liked songs and playlists between the app's local SQLite library and their YTM account. When signed out, everything stays exactly as it is today (local-only).

**Hard requirement (non-negotiable):** Do NOT break, change, or disturb anything that exists today. Playback, WebView navigation, downloads, likes-while-playing, and every existing UI path must behave identically. Sync only **adds** rows to the local DB and **posts existing notifications**. It never rewrites playback logic, never navigates the WebView, and never touches the audio engine.

---

## 1. Design decisions (already decided — implement these)

- **Sync direction:** two-way (pull YTM → app, push app → YTM).
- **Conflict strategy on pull:** **merge, never overwrite.** Pull adds tracks that exist on YTM but are missing locally; it NEVER deletes local-only tracks or reorders local lists.
- **Push semantics:** app → YTM. New tracks added in-app to a synced playlist get pushed up; playlists created in-app with `synced = 0` get created on YTM. Local track removals from a synced playlist MAY delete on YTM (this is expected, standard sync behavior).
- **Trigger:** **auto** sync on sign-in (and on app launch if already signed in) **plus** a manual **"Sync Now"** action in the status-bar menu.
- **Signed-out behavior:** completely unchanged. No sync runs, no prompts, no UI changes.

---

## 2. How it works — InnerTube (zero cost, no API key)

YouTube Music is accessed through its own internal JSON API (InnerTube):

- Base URL: `https://music.youtube.com/youtubei/v1/<endpoint>?alt=json&key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8`
  - The `key` is the well-known public web-client key used by the YTM web player. It is public and hardcoded in the page; do not invent a different one. (Reference: open-source ytmusicapi / yt-dlp.)
- **Auth:** the user's own session cookies, already present in `WKWebsiteDataStore.default()` (the same store the embedded WebView uses). Read `SAPISID` plus `__Secure-1PAPISID` / `__Secure-3PAPISID` from `WKWebsiteDataStore.default().httpCookieStore.getAllCookies`.
- **Authorization header:** `Authorization: SAPISIDHASH <timestamp>_<hash>` where:
  1. `origin = "https://music.youtube.com"`
  2. `timestamp = Int(Date().timeIntervalSince1970)`
  3. `msg = timestamp + " " + sapisid + " " + origin`
  4. `hash = SHA-1(msg) hex`
  5. header value = `SAPISIDHASH <timestamp>_<hash>`
  - This is the standard, publicly documented algorithm (same one the web client uses).
- Additional required headers: `X-Goog-AuthUser: 0`, `Content-Type: application/json`, a normal browser `User-Agent`, and the same `Origin: https://music.youtube.com`.
- **Request body:** JSON with `context.client` — the YTM web client context. Minimum viable (stable across versions; matches ytmusicapi):
  ```json
  {
    "context": {
      "client": {
        "clientName": "WEB_REMIX",
        "clientVersion": "1.20240902.01.00",
        "hl": "en",
        "gl": "US"
      }
    }
  }
  ```
  Plus the endpoint-specific params documented below.

### Endpoints needed

| Purpose | Endpoint | Body params |
| :-- | :-- | :-- |
| List account playlists | `browse` | `{ "browseId": "FEmusic_liked_playlists" }` |
| Liked songs list | `browse` | `{ "browseId": "FEmusic_liked_songs" }` |
| Playlist contents | `browse` | `{ "browseId": "<playlist browseId>" }` (a `VLPL...` / `VL<playlistId>` string or the `PL...`-derived browseId returned by the playlists list) |
| Create playlist | `playlist/create` | `{ "title": "...", "videoIds": ["<videoId>", ...] }` |
| Add items to playlist | `playlist/add` | `{ "playlistId": "PL...", "videoIds": ["<videoId>", ...] }` |
| Remove item from playlist | `playlist/remove` | `{ "playlistId": "PL...", "videoId": "<videoId>", "setVideoIds": [ ...full remaining list... ] }` |
| Like a video | `like/like` | `{ "target": { "videoId": "<videoId>" } }` |
| Unlike a video | `like/removeLike` | `{ "target": { "videoId": "<videoId>" } }` |

### Response parsing notes (stable, known fields)

- **Playlist list** (`browse` → `FEmusic_liked_playlists`): response contains a shelf/`gridPlaylistRenderer` / `lockupViewModel` items. Each playlist exposes a playlist ID (`PL...`), title, and the browseId used to fetch its contents (`VLPL...`). **Do not hardcode selector strings into the manager** — implement a small, tolerant extractor that:
  1. prefers `playlistId` fields,
  2. falls back to regexing `playlistId` / `browseId` tokens from the raw JSON (walk the JSON as `[String: Any]`),
  3. falls back to the documented ytmusicapi parsing patterns.
- **Playlist contents:** repeated music responsive track renderers / `musicResponsiveListItemRenderer` with: `videoId`, `title` (`runs[].text`), artist (`flexColumns` → `runs[].text`), thumbnail (`thumbnails[last].url`), `lengthText`/`duration` (e.g. `"3:45"`).
- **Liked songs list** (`FEmusic_liked_songs`): same track-renderer shape as playlist contents.
- Pagination: `continuation` tokens. For v1, handle the first page only is **NOT acceptable** for liked songs (may be huge). Implement continuation loop: if response contains `continuationCommand.token`, append `{ "continuation": "<token>", "context": {...} }` to a follow-up `browse` call and repeat until no token (cap total pages at e.g. 10).

---

## 3. Database migration (v5) — purely additive

File: `Sources/Mooziac/Managers/LocalDatabaseManager.swift`

- Add `migrateToV5()` following the existing pattern at `applySchemaIfNeeded()` (lines ~281-319). Add:
  ```swift
  if userVersion < 5 { migrateToV5() }
  ```
- `migrateToV5()` body (idempotent, use `columnExists(table:column:)` which already exists at line 321):
  ```sql
  ALTER TABLE playlists ADD COLUMN yt_playlist_id TEXT;
  ALTER TABLE playlists ADD COLUMN synced INTEGER NOT NULL DEFAULT 0;
  CREATE INDEX IF NOT EXISTS idx_playlists_yt_playlist_id ON playlists(yt_playlist_id);
  ```
  then `setUserVersion(5)`.
- **No changes to `playlist_items` or `liked_songs` tables.** `playlist_items` already supports `ref_type = 'yt'` + `yt_video_id`. `liked_songs` already has `synced` + `source_type`.
- **Note:** `currentSchemaVersion` (line 188) says `3` but real schema is v4 — this constant is informational/unused for migration gating (gating uses `PRAGMA user_version`). Do not "fix" it as part of this feature unless it causes a build failure; leave it.

### New / extended record types

- Extend `PlaylistRecord` (lines 67-81) with optional `ytPlaylistId: String?` and `synced: Bool`, defaulting to `nil` / `false`. Update:
  - `fetchPlaylists()` (line 863) to select `yt_playlist_id, synced` and pass them through.
  - The `PlaylistRecord(...)` construction in `fetchPlaylists` only (line 881). Do NOT break the memberwise init used elsewhere — keep `ytPlaylistId`/`synced` as defaulted params at the END of the init.
- Add new DB methods in `LocalDatabaseManager` (all threaded through the existing `db` + statement pattern):
  - `upsertPlaylistFromYTM(ytPlaylistId: String, name: String) -> String?` — insert with a fresh UUID local id, `yt_playlist_id` set; if a row with that `yt_playlist_id` exists, `UPDATE` name and return its existing id. `synced = 1`.
  - `setPlaylistSynced(id: String)` — `UPDATE playlists SET synced = 1 WHERE id = ?`.
  - `setPlaylistYTMID(id: String, ytPlaylistId: String)` — for in-app created playlists after `playlist/create` returns.
  - `fetchUnsyncedPlaylists() -> [PlaylistRecord]` — `WHERE synced = 0`.
  - `fetchSyncedPlaylists() -> [PlaylistRecord]` — `WHERE yt_playlist_id IS NOT NULL` (used for push of item diffs).
  - `playlistItemIDs(playlistID: String) -> Set<String>` — existing `yt_video_id`s for diffing (can reuse `fetchPlaylistItems`).

---

## 4. New file: `Sources/Mooziac/Managers/YTMClient.swift`

Public `final class YTMClient` (singleton `shared` or plain struct — pick what fits the codebase; existing managers use `.shared`).

Responsibilities:
- Read cookies: `WKWebsiteDataStore.default().httpCookieStore.getAllCookies { ... }` → build a `[String: String]` of cookie name → value for `SAPISID`, `__Secure-1PAPISID`, `__Secure-3PAPISID`.
- Compute `SAPISIDHASH` (section 2). Use `CryptoKit` (already available on macOS 10.15+; the project targets modern macOS).
- `func browse(browseId: String, continuation: String? = nil, completion: ...)` — POST to `youtubei/v1/browse`; returns parsed `[String: Any]`.
- `func createPlaylist(title: String, videoIds: [String], completion: ...)` — `playlist/create`; extract `playlistId` from response.
- `func addToPlaylist(playlistId: String, videoIds: [String], completion: ...)` — `playlist/add`.
- `func like(videoId: String, liked: Bool, completion: ...)` — `like/like` / `like/removeLike`.
- Parsing helpers (section 2 response notes).
- **Error handling:** any non-2xx or missing cookie → completion failure with a descriptive message. Never crash. Never throw across async boundaries in a way that touches the main thread unguarded.

Implementation notes:
- Use `URLSession` (the app already uses `URLSession.shared` in several managers — consistent).
- All networking on a background queue; callbacks hop to `DispatchQueue.main` if they will touch UI/DB-owned state.
- Do NOT call the fragile DOM/click approach. The existing `LikedSongsManager.clickLikeButton()/readLikeState()` (`LikedSongsManager.swift:163-214`) stays untouched for its current (unwired) role; the new sync uses the API endpoints instead.

---

## 5. New file: `Sources/Mooziac/Managers/PlaylistSyncManager.swift`

Public `final class PlaylistSyncManager` with `static let shared`.

State & guards:
- `private var isSyncing = false` — single-flight guard.
- `private var isPullInProgress = false`, `private var isPushInProgress = false`.
- Public `var isSignedIn: Bool { LikedSongsManager.shared.isSignedIn }`.

Entry points:

```swift
public func syncNow() {          // manual + auto path
    guard !isSyncing,
          LikedSongsManager.shared.isSignedIn,
          NetworkMonitor.shared.isReachable else { return }
    isSyncing = true
    pushLocalToAccount { [weak self] in
        self?.pullAccountToLocal {
            self?.isSyncing = false
            self?.postLibraryUpdated()
        }
    }
}

public func pullAccountToLocal(completion: @escaping () -> Void)
public func pushLocalToAccount(completion: @escaping () -> Void)
```

### Pull: account → local (merge, never delete)

1. `YTMClient.browse("FEmusic_liked_playlists")` → list of `(ytPlaylistId, name, browseId)`.
2. For each playlist (sequential or small-batch):
   - localID = `upsertPlaylistFromYTM(ytPlaylistId:name:)`.
   - Fetch contents via `browse(browseId)` with continuation loop.
   - Diff: `existingVids = playlistItemIDs(localID)`. For each remote track with non-empty `videoId` NOT in `existingVids` → `appendPlaylistItem(PlaylistItemRecord(playlistID: localID, sortOrder: <index>, refType: "yt", refID: videoId, ytVideoId: videoId, title:, artist:, artworkUrl:, duration:))` (use the existing `PlaylistItemRecord` initializer with defaults). **Do NOT remove local-only items.** Keep remote order only for newly added items (append at end is acceptable; do not reorder existing rows).
3. Liked songs: `YTMClient.browse("FEmusic_liked_songs")` + continuation loop. For each track: if `!LikedSongsManager.shared.isLiked(videoId:)` → `LocalDatabaseManager.shared.addLikedSong(LikedSongRecord(videoId:, title:, artist:, album:, artworkUrl:, duration:, dateLiked: now, synced: true, sourceType: "ytm"))` (upserts on conflict, does not touch `date_liked`).
4. Completion → main thread.

### Push: local → account

1. **Unsynced playlists** (`fetchUnsyncedPlaylists()` where `synced = 0` and `yt_playlist_id IS NULL`): for each, collect its items' `yt_video_id`s (skip items without one), call `YTMClient.createPlaylist(title:videoIds:)`, then `setPlaylistYTMID(id:ytPlaylistId:)` + `setPlaylistSynced(id:)`. If `videoIds` empty, still create the playlist with the title, mark synced, skip add.
2. **Synced playlist item additions:** for each synced playlist (`fetchSyncedPlaylists()`), diff remote vs local? No — v1 is simpler and safe: push **only** newly added local items to synced playlists is complex (requires comparing remote). Keep v1 scope tight:
   - **v1 push scope = playlists created inside the app** (unsynced). For items added later into a synced playlist, set that playlist's `synced = 0` in `appendPlaylistItem`/`appendTrack`-family flows (see section 6 hook) so the next sync re-creates... no, re-creating would duplicate. Instead:
   - Mark a synced playlist as "dirty" (add column `dirty INTEGER DEFAULT 0` in v5 instead of relying on `synced` flip). **Decision: use a dedicated `dirty` column.** Then push for dirty synced playlists = `playlist/add` the missing local `yt_video_id`s (diffed against current remote, fetched in the pull step). Keep it simple: during `syncNow`, after pull, for each dirty synced playlist fetch remote item ids, add the local ones missing, then clear `dirty`.
3. **Liked songs push:** reuse existing DB flags — `fetchUnsyncedLikedSongs()` (`LocalDatabaseManager.swift:779`), for each call `YTMClient.like(videoId:liked: true)` then `setLikedSongSynced(videoId:)` (`:734`). Batch sequentially; skip if network drops (`NetworkMonitor`).

### Notifications (post on main thread ONLY, at the end)

- `NotificationCenter.default.post(name: NSNotification.Name("Mooziac_LibraryUpdated"), object: nil)` — playlists list UI already observes this (`SettingsPanel.swift:1002` refresh via `Core.swift:247`; `PlaylistLibraryView.swift:369`).
- `NotificationCenter.default.post(name: LikedSongsManager.likedSongsUpdatedNotification, object: nil)` — liked songs UI already observes this (`Core.swift:259`).

These two posts are the ONLY UI interaction the whole feature performs.

---

## 6. Integration points (small, surgical edits)

1. **Sign-in trigger** — observe `LikedSongsManager.signInStatusChangedNotification` (already defined at `LikedSongsManager.swift:8`, currently unobserved). Add an observer (e.g. in `PlaylistSyncManager.shared`'s init or `AppDelegate`) that calls `syncNow()` when `userInfo`/state flips to signed in. Also on app launch (in `AppDelegate.applicationDidFinishLaunching`, `Sources/Mooziac/App/AppDelegate.swift:14`) fire `syncNow()` after a short delay if `isSignedIn` (defer ~2-3s so cookies/WebView are ready — mirror existing patterns like `DispatchQueue.main.asyncAfter`).
2. **Dirty marking on local edits to synced playlists** — in `PlaylistManager.swift`, the methods `appendPlaylistItem`/`appendLocalTracks`/`appendTrack`/`appendHistoryItem`/`appendLikedSong`/`appendCurrentPlayingTrack`/`removeCurrentPlayingTrackFromPlaylist`/`reorderItems`/`renamePlaylist` currently call `LocalDatabaseManager` directly. After the successful DB call, add: `if let pl = fetchPlaylists().first(where: { $0.id == playlistID }), pl.ytPlaylistId != nil { LocalDatabaseManager.shared.markPlaylistDirty(playlistID) }`. Implement `markPlaylistDirty(id:)` in `LocalDatabaseManager` (`UPDATE playlists SET dirty = 1 WHERE id = ?`). **This is a one-line addition per method — do not refactor these methods.**
3. **Manual "Sync Now"** — in the status-bar menu (`Sources/Mooziac/Core/StatusItemManager/ContextMenu.swift`), add a menu item **"Sync with YouTube Music"** calling `PlaylistSyncManager.shared.syncNow()`. Only include/enable it when signed in (refresh on `signInStatusChangedNotification`). Place near the existing "Reset Login (Fresh Start)" / "Reload Player Engine" items (`ContextMenu.swift:161-162`) — do not modify those existing actions.
4. **`renamePlaylist` for synced playlists** — push rename? v1: skip (note as future). Renaming a synced playlist in-app marks it dirty but does NOT rename on YTM in v1. Keep behavior predictable: on pull, do not overwrite a locally-renamed synced playlist's name (upsert only sets name when local name is empty OR playlist is new). Simplest: `upsertPlaylistFromYTM` sets name only on first import.

---

## 7. Safety guardrails (must all hold)

- Sync never touches: `NowPlayingManager`, `NativeAudioPlayer`, `PlayerControls`, `YTMWebView` navigation, `DownloadManager`, `HistoryManager`, `LocalLibraryManager`, or any `Views/` file. **No UI files change except the status menu item.**
- All DB writes go through `LocalDatabaseManager` methods. DB is thread-safe already (`SQLITE_OPEN_FULLMUTEX`, `busy_timeout=5000`, WAL).
- Single-flight `isSyncing` — no overlapping syncs.
- Skip everything when `!isSignedIn || !NetworkMonitor.shared.isReachable`.
- Pull is merge-only: never DELETE local playlist items, never DELETE local liked songs, never reorder existing rows.
- Failure isolation: per-playlist or per-track failures log via `print("[YTMClient] ...")` and continue; a failed sync does not corrupt state. Never throw uncaught.
- Do not run sync synchronously on the main thread; use `URLSession` + main-thread hops only for the final notification posts.
- No crash on missing cookies: if SAPISID absent → abort sync silently (signed-in state from cookies and DOM may disagree; just guard).

---

## 8. What NOT to do

- Do NOT add any API key config, secrets, or user-credential storage. Everything uses the user's existing session cookies from `WKWebsiteDataStore.default()`.
- Do NOT modify: `ObserverBridge.swift` JS, `YTMWebView.swift` (navigation/login/cookies logic), `NowPlayingManager.swift` internals, any `Views/Player/...` file (except none — the status menu item lives in `StatusItemManager` which is `Core/`), `PlayerControls.swift`.
- Do NOT wire up or change the existing dead `LikedSongsManager.syncUnsyncedToAccount()` method (`LikedSongsManager.swift:125-161`). Leave it. (It becomes redundant once the API path exists; do not delete it in this update.)
- Do NOT "fix" unrelated things (e.g. `currentSchemaVersion`, the unused `signInStatusChangedNotification` observers elsewhere) — out of scope.
- Do NOT create any UI beyond the one status-menu item.

---

## 9. Build & verification checklist

```bash
swift build              # must compile clean (all targets/module)
swift build -c release   # release must also compile
./build_app.sh           # full pipeline: bundle + sign + launch
```

Manual test matrix (run the app via `build_app.sh`):
1. **Signed out:** create a playlist, like a song, play offline + online. Everything must behave exactly as before. No sync menu action visible (or disabled).
2. **Sign in:** after Google login completes and cookies land, auto-sync runs silently. Verify:
   - YTM liked songs now appear in the app's Liked Songs tab.
   - YTM playlists now appear in the app's Playlists tab, playable (online playback via existing `playOnlineVideo` path), downloadable via existing "Download All".
   - No playback interruption, no WebView navigation, no UI glitches.
3. **Push:** in-app create a playlist with a few tracks → run "Sync Now" → open YTM in the embedded browser → verify the playlist + tracks exist on the account. Like a song while signed out → sign in → sync → verify it appears on the account.
4. **Merge safety:** create playlist in app with tracks A,B; create same-titled playlist on YTM with C (no link — different local rows, fine). More important: link a playlist, add a local track, pull again → local track remains, YTM's new tracks appear. Nothing removed.
5. **Idempotence:** run sync twice in a row → no duplicate playlists, no duplicate items, no duplicate liked songs.
6. **Offline:** sync while offline → no crash, no state change; sync resumes when network returns.
7. **DB migration:** existing installs migrate v4 → v5 without data loss (playlists/liked songs/items intact).

---

## 10. Effort breakdown (rough)

1. DB v5 migration + `PlaylistRecord` extension + new `LocalDatabaseManager` methods — small.
2. `YTMClient` (cookies, SAPISIDHASH, browse/playlist/like endpoints, tolerant parsing + continuation) — bulk of the work.
3. `PlaylistSyncManager` (pull-merge, push, dirty marking, notifications, single-flight guard) — medium.
4. Integration: sign-in observer, launch trigger, dirty hooks in `PlaylistManager`, one status-menu item — small.
5. Build + manual test matrix above — required.