# Module Architecture

Mooziac is a single SPM module (`Mooziac`) but has clear logical subsystems. This document describes each subsystem's responsibility, its main types, and its interface to the rest of the app. Deep per-file detail is in `99_APPENDIX/RAW_DISCOVERY_NOTES/`.

## Subsystem map

| Subsystem | Folder(s) | Core types | Responsibility |
| :--- | :--- | :--- | :--- |
| App | `App/` | `AppDelegate`, `BackgroundMediaController` | Lifecycle, background sleep prevention |
| Core | `Core/` | `MainViewController`, `DisplayManager`, `NowPlayingManager`, `ObserverBridge`, `PlayerControls`, `Queue`, `StatusItemManager`, `StatusItemPanel`, `ContextMenu` | Central state, playback coordination, menu-bar shell |
| Services | `Managers/` | 12 singletons + `SyncedLyricsParser` | Persistence, content, integration |
| Models | `Models/` | 9 files | Pure data + enums |
| Audio | `Audio/` | `NativeAudioPlayer`, `EdgeVolumeEngine`, `AppVolumeManager`, `AudioRouteMonitor`, `ClickSound` | Playback & system audio |
| Web | `Web/` | `YTMWebViewContainer`, `URLFilter` | WebKit hosting, filtering |
| Input | `Input/` | `GestureMappingManager`, `GlobalHotKeyManager`, `KeyboardCommandHandler` | Gesture & key input |
| Views | `Views/` | ~27 UI types | All rendering |
| Support | `Support/` | `NSImage.floppyDiskIcon` | Minor helpers |

## 1. App subsystem

- `main.swift` (7 lines): bootstrap.
- `AppDelegate`: boot sequence, Edit menu, legacy key purge, terminate hook.
- `BackgroundMediaController`: `IOPMAssertion` + `beginActivity` to keep audio alive through lock/sleep.

## 2. Core subsystem

- **`NowPlayingManager`** — the hub. Owns `PlaybackState`, `engineMode`, the observer callback list, session restoration, sleep/wake handling, network-aware behavior, WebContent recovery. Exposes `attach(to:)` (WKWebView), `evaluateJS`, `notifyObservers`, `updateSystemNowPlayingInfo`.
- **`ObserverBridge`** — the JS↔Swift bridge: injects `ytmObserver` script; receives `nowPlayingHandler` messages; parses `PlaybackState`; maintains `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`; performs queue/EQ/next/prev JS.
- **`PlayerControls`** — command dispatch. Same public API regardless of engine; internally routes to JS or `NativeAudioPlayer`.
- **`Queue`** — queue fetch, dedup, reorder (DOM + data model), automix, up-next.
- **`MainViewController`** — top-level container; hosts player pill, browser container (`PassthroughBrowserContainerView` + `HeaderView`), offline/playlist libraries; search routing (offline fuzzy match vs online autoplay JS).
- **`DisplayManager`** — multi-screen geometry, notch detection, safe-top boundary, frame clamping.
- **`StatusItemManager`/`StatusItemPanel`/`ContextMenu`** — menu-bar item, panel, context menu, dock↔float dragging, scroll-volume.

## 3. Service subsystem (Managers/)

| Manager | Responsibility | Key state |
| :--- | :--- | :--- |
| `LocalDatabaseManager` | SQLite (v4): tracks, playlists, playlist_items, listening_history, liked_songs; 41 statements | connection, schema version |
| `LocalLibraryManager` | Scans `~/Music/Mooziac` + Offline; extracts metadata/artwork; like toggling | allTracks cache |
| `PlaylistManager` | Playlist CRUD, reorder, cross-library insertion, playback contexts | playlists, activeContext |
| `DownloadManager` | `yt-dlp`+`ffmpeg` jobs; queue; progress; finalize; delete | queue, activeJob, batch counts |
| `LyricsManager` | LRCLib/Lyrics.ovh fetch + match + cache + time-driven resolution | cache, fetched state |
| `SyncedLyricsParser` | LRC parsing + plain→LRC synthesis | — (pure) |
| `HistoryManager` | Recent-played dedup + cap; seeds from last track | record buffer |
| `LikedSongsManager` | Liked-song persistence + YTM DOM sync + sign-in detection | synced set |
| `DiscordRPCManager` | Discord IPC: handshake + activity frames + reconnect loop | connection state |
| `TrackNotificationManager` | Track-change banners with artwork | last notification |
| `NetworkMonitor` | `NWPathMonitor` reachability → notifications | isReachable |
| `AppArtworkHelper` | Artwork memory cache + thumbnail files + image processing | memory cache, ioQueue |

## 4. Models

Pure data + enums (`PlaybackState`, `LocalTrack`, `RepeatMode`, `PlaybackEngineMode`, `PlayerDesign`, `ProgressStyle`, `GestureType`/`GestureAction`, `LikedSongRecord`, `LaunchAnimationTimeline`).

## 5. Audio subsystem

- `NativeAudioPlayer`: offline AVPlayer engine (queue/shuffle/repeat/seek/ff/rw/like/volume).
- `EdgeVolumeEngine`: private-Multitouch right-edge volume engine (`VolumeController`, `ActiveEngineBox`).
- `AppVolumeManager`: system↔app volume mapping.
- `AudioRouteMonitor`: device-change & lock/sleep auto-pause.
- `ClickSound`: system feedback sounds.

## 6. Web subsystem

- `YTMWebViewContainer`: `WKWebView` configuration (UA, autoplay, media types), `YTMBlockRules` content-rule JSON, crash recovery (`recoveryWatchdog` 20 s), restore-and-play JS, offline overlay.
- `URLFilter`: text/link heuristic (content blocking actually lives in YTMWebView).

## 7. Input subsystem

- `GestureMappingManager`: gesture→action mapping; corner-tap toasts.
- `GlobalHotKeyManager`: global key monitors.
- `KeyboardCommandHandler`: key command interception + overlays.

## 8. Views

See `05_UI/UI_ARCHITECTURE.md` for the full view breakdown.

## 9. Support

`NSImage.floppyDiskIcon` only.

## Central modules (hubs)

- `NowPlayingManager` — depends on most managers, engines, views (indirectly); everything depends on its state.
- `MainViewController` — couples the player view, web view, and both libraries.
- `LocalDatabaseManager` — backend for library/playlist/history/likes.
- `LocalLibraryManager` — shared by native player, library views, playlist manager, download manager.

## Isolated modules

- `ClickSound`, `Support/AppExtensions`, `URLFilter`, `LaunchOverlayView` — near-zero coupling.
- `SyncedLyricsParser` — pure, only consumed by `LyricsManager`.

## Single points of failure (see `15_ISSUES_AND_RISKS/RISK_AREAS.md`)

- `NowPlayingManager` (all state flows through it).
- `LocalDatabaseManager` (all persistence flows through it).
- The JS bridge contract (`ObserverBridge` + YTM DOM).
- Private Multitouch ABI (`EdgeVolumeEngine`).