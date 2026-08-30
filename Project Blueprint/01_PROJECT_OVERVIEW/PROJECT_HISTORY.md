# Project History

Sources: `CHANGELOG.md` (formerly `PROJECT_CHANGES_LOG.md`), `AGY.md` work log, git log.

> Note: the git repository history (`git log`) only contains ~15 recent commits (recent work is uncommitted in the working tree; the tree is mid-refactor with many staged renames). The authoritative history below is derived from `CHANGELOG.md` / `AGY.md`.

## Origins

Mooziac began as **YTMMenuBar** — a menu-bar wrapper around YouTube Music in a `WKWebView`. Early iterations also referenced a `SpotifyPlayerView`/`SearchSuggestionManager`/`SearchResultsOptionsView` (since removed; a legacy `spotifyPlayerDidTapLogin` method name still survives in `MainViewController.swift:525`). The app is MIT-licensed, targets macOS 13+, and has reached v1.0.0.

## Major development eras

### 1. WebKit player core
- Embedded YouTube Music web view; injected JS to observe and control playback.
- Custom `YTMWebView` with ad/telemetry URL filtering (content rule list `YTMBlockRules`), autoplay policies, WebContent process-crash recovery, `restoreAndPlayJS` session restore.
- `URLFilter.swift` started as a link-detection heuristic; the actual content-block JSON moved into `YTMWebView.swift`.

### 2. Native player & queue fidelity
- `NativeAudioPlayer` (AVFoundation) added for local files with queue/shuffle/repeat.
- **Queue fidelity work**: reordered-queue next/prev (`nextTrack`/`previousTrack` now inspect the DOM queue), queue drag-reorder persisted via DOM `insertBefore` + Polymer data-model splice, duplicate queue-item dedup (dual `ytmusic-player-queue-item` nodes), Up-Next auto-radio mix trigger.

### 3. Multitouch gesture engine
- `EdgeVolumeEngine` — right-edge volume swipe via private Multitouch framework; **crash fix**: retained `CFArray` of `MTDevice` C objects after `MTDeviceCreateList` EXC_BAD_ACCESS; debounced restart on lock/wake.
- Corner-tap gestures (bottom-right 2/3 taps → next/prev; bottom-left 2 taps → play/pause).

### 4. Dynamic Island player & design system
- 3-row 8px-grid pill player with waveform seek, reactive buttons, ambient artwork theming (`ArtworkTheme`), dual design engine (Ambient / OLED / Warm Off-White themes).
- Liquid Glass (Control Center style) theme was **implemented then rolled back** (AGY work log, 2026-08-19).

### 5. Data layer
- `LocalDatabaseManager` (SQLite, schema now at **v4**, 5 tables: tracks, playlists, playlist_items, listening_history, liked_songs; 9 indexes).
- `LocalLibraryManager` (file scanning + ID3/AVAsset metadata + thumbnail cache), `PlaylistManager`, `DownloadManager` (`yt-dlp`+`ffmpeg`), `HistoryManager`, `LikedSongsManager`.

### 6. Lyrics HUD
- `LyricsManager` (LRCLib → Lyrics.ovh), `SyncedLyricsParser` (`[mm:ss.xx]`), `CenteredMenuBarLyricsWindowController` HUD with real-time line highlighting and status toasts.

### 7. Background & system integration
- `BackgroundMediaController` (IOPMAssertion sleep prevention), `AudioRouteMonitor` (auto-pause on device change / lock / sleep), `NetworkMonitor` (offline fallback), `DiscordRPCManager` (Rich Presence), `TrackNotificationManager` (banners).

### 8. Recent restructure (Unreleased, per CHANGELOG)
- Repo reorganized into feature folders: `App/`, `Core/`, `Models/`, `Managers/`, `Audio/`, `Views/`, `Web/`, `Input/`, `Support/`.
- Assets centralized into `Resources/`; `build_app.sh` copies exclusively from `Resources/`.
- Dead code removed (unused `AppTheme`, `trackpad_visualizer.html`, root `MOOZIAC.png`), `.build/` + `.DS_Store` untracked.
- Models extracted into `Models/`.

### 9. Most recent sessions (AGY.md work log, 2026-08-19)
- Full-codebase audit + `AGY.md` creation.
- Liquid Glass theme feasibility → implementation → **rollback** (theme suite restored to `.adaptive`, `.darkMode`, `.glassMode`).
- Liked-songs playback, downloads & cross-library playlist insertion with right-click context menus (PlaylistManager `appendTrack`/`appendHistoryItem`/`appendLikedSong`; Liked Songs tab; ~55 context-menu items).

## Git log (most recent commits, most recent first)

```
5b94545 Updated tutorial window and trackpad.html … (native gesture tutorial)
529782e Enforced initial paused playback state … tutorial window under status bar
34756f4 Integrated exact trackpad.html UI inside native NSPanel gesture tutorial window
c6165f9 Implemented 100% native Swift AppKit gesture tutorial window …
7e49552 Updated trackpad.html to display ONLY the clean trackpad visualizer
c4c67cd Fixed text edge clipping … gesture tutorial loop for 2-taps/3-taps
5a01ac6 … Option B as an ultra-mini 340px HUD card
d2cf5ae … compact small floating HUD panel …
b202827 Added native SwiftUI presentation previews … trackpad.html
0a22d99 Designed Apple Native Trackpad Gesture Tutorial Card screen …
f451a0d Integrated ultra-refined Apple System Pro HUD pill …
d33dc67 Rolled back trackpad.html to top-right floating HUD … (commit 14b545b)
42b4346 … authentic Apple Silver anodized glass trackpad color …
240d97b … standalone Apple Glass Trackpad canvas …
2fd1e00 Fixed volume gesture direction (UP increases volume …)
```

The commit history is dominated by iteration on the **trackpad gesture tutorial** (`trackpad.html` + `NativeGestureTutorialWindowController`), with the broader codebase restructuring currently uncommitted.