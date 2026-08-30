# File Catalog

Every meaningful file in the repository, one entry per file. Exhaustive per-file detail (imports, classes, functions, state, events, side effects, callers) lives in `99_APPENDIX/RAW_DISCOVERY_NOTES/` under the work package noted in the last column.

Subsystem legend: **App**=lifecycle · **Core**=controllers/state · **Mgr**=managers · **Models** · **Audio** · **UI** · **Web** · **Input** · **Supp**=support.

## Swift source (`Sources/Mooziac/`) — 60 files

| File | Lines | Subsys | Purpose | Deep detail |
| :--- | ---: | :--- | :--- | :--- |
| `App/main.swift` | 7 | App | Entry point; creates `NSApplication`, attaches `AppDelegate`, runs loop | 01 |
| `App/AppDelegate.swift` | 70 | App | Launch init: accessory policy, legacy-key purge, sleep prevention, engines, monitors, status item, launch animation; Edit menu; terminate hook | 01 |
| `App/BackgroundMediaController.swift` | 54 | App | `IOPMAssertion` + `ProcessInfo.beginActivity` to keep audio alive on lock/sleep | 01 |
| `Audio/AppVolumeManager.swift` | 101 | Audio | App-volume ↔ system-volume bridging; per-app volume mode; overlays | 02 |
| `Audio/AudioRouteMonitor.swift` | 126 | Audio | Detects audio device changes & screen lock/sleep; auto-pause; CoreAudio listener | 02 |
| `Audio/ClickSound.swift` | 14 | Audio | System feedback sound effects (`stop()` is a no-op) | 02 |
| `Audio/EdgeVolumeEngine.swift` | 520 | Audio | Private Multitouch right-edge volume engine; touch stream, region math, clamps, haptics | 02 |
| `Audio/NativeAudioPlayer.swift` | 442 | Audio | Offline `AVPlayer` engine: queue, shuffle, repeat, time observer, end handling, state broadcast | 02 |
| `Core/DisplayManager.swift` | 92 | Core | Screen geometry: display ID, notch detection, safe top boundary, frame clamping | 01 |
| `Core/MainViewController.swift` | 529 | Core | Central container; hosts player/browser/libraries; search router; delegate wiring | 01 |
| `Core/NowPlayingManager/NowPlayingManager.swift` | 273 | Core | Central playback-state singleton; online/offline engine switch; observers; sleep/wake & recovery | 01 |
| `Core/NowPlayingManager/ObserverBridge.swift` | 461 | Core | Injects `ytmObserver` JS; handles `nowPlayingHandler` messages; Now Playing / media keys; queue/EQ JS | 01 |
| `Core/NowPlayingManager/PlayerControls.swift` | 590 | Core | Dispatches play/pause/next/prev/seek/volume/like/shuffle/repeat to JS or native | 01 |
| `Core/NowPlayingManager/Queue.swift` | 635 | Core | Queue fetch/sync, drag-reorder, automix, up-next snapshot | 01 |
| `Core/StatusItemManager/StatusItemManager.swift` | 495 | Core | Menu-bar item, panel/popover toggle, scroll-volume, dock↔float drag, key monitor | 01 |
| `Core/StatusItemManager/StatusItemPanel.swift` | 29 | Core | Custom transparent glass `NSPanel` wrapper (floating/normal levels) | 01 |
| `Core/StatusItemManager/ContextMenu.swift` | 251 | Core | Right-click context menu (prefs, reset position, restart engine, quit, gesture toggles) | 01 |
| `Input/GestureMappingManager.swift` | 79 | Input | Configurable gesture→action mapping; corner-tap overlays | 02 |
| `Input/GlobalHotKeyManager.swift` | 54 | Input | Global key monitors (Ctrl+Opt+Space, Cmd+Shift+Space, arrows, L) | 02 |
| `Input/KeyboardCommandHandler.swift` | 62 | Input | Space/enter/escape command interception & overlays | 02 |
| `Managers/AppArtworkHelper.swift` | 277 | Mgr | Artwork caching (memory + thumbnails), image processing | 04 |
| `Managers/DiscordRPCManager.swift` | 412 | Mgr | Discord Rich Presence over UNIX socket; handshake + activity frames; reconnect loop | 04 |
| `Managers/DownloadManager.swift` | 1013 | Mgr | `yt-dlp`+`ffmpeg` download pipeline; queue, progress, finalize, delete | 03 |
| `Managers/HistoryManager.swift` | 176 | Mgr | Recently-played tracking with dedup + cap; seeds from last track | 04 |
| `Managers/LikedSongsManager.swift` | 214 | Mgr | Liked-songs persistence + YouTube DOM sync + sign-in detection | 04 |
| `Managers/LocalDatabaseManager.swift` | 1243 | Mgr | SQLite layer: 5 tables, 41 statements, migrations to v4, fullmutex | 03 |
| `Managers/LocalLibraryManager.swift` | 490 | Mgr | Thread-safe folder scan (`~/Music/Mooziac`, Offline), metadata extraction, like toggling | 03 |
| `Managers/LyricsManager.swift` | 507 | Mgr | Lyrics fetch (LRCLib/Lyrics.ovh), matching gates, caching, time-driven line resolution | 04 |
| `Managers/NetworkMonitor.swift` | 88 | Mgr | `NWPathMonitor` reachability; offline/reconnected notifications | 04 |
| `Managers/PlaylistManager.swift` | 865 | Mgr | Playlist CRUD, track associations, reorder, playback contexts, cross-library insertion | 03 |
| `Managers/SyncedLyricsParser.swift` | 155 | Mgr | `[mm:ss.xx]` LRC parser + plain→LRC synthesis | 04 |
| `Managers/TrackNotificationManager.swift` | 90 | Mgr | Track-change banner notifications with artwork | 04 |
| `Models/GestureMappingModels.swift` | 51 | Models | `GestureType`, `GestureAction` enums + mapping struct | 04 |
| `Models/LaunchAnimationTimeline.swift` | 27 | Models | Launch animation timeline model (fields largely unused) | 04 |
| `Models/LikedSongRecord.swift` | 32 | Models | Liked song row model (id, title, artist, artworkUrl, timestamp) | 04 |
| `Models/LocalTrack.swift` | 75 | Models | Local audio file model (id, title, artist, album, duration, fileURL, artwork, lrcURL, isLiked, dateAdded, ytVideoId) | 04 |
| `Models/PlaybackEngineMode.swift` | 5 | Models | `.online` / `.offline` enum | 04 |
| `Models/PlaybackState.swift` | 28 | Models | Current playback snapshot (title, artist, artwork, times, isPlaying, isLiked, volume, repeat, shuffle) | 04 |
| `Models/PlayerDesign.swift` | 23 | Models | Theme enum (`.adaptive`, `.darkMode`, `.glassMode`, `.native`→maps to `.adaptive`); posts `YTM_playerDesignChanged` | 04 |
| `Models/ProgressStyle.swift` | 31 | Models | Progress style enum; posts `ProgressStyleDidChange` | 04 |
| `Models/RepeatMode.swift` | 12 | Models | `.off`, `.all`, `.one` | 04 |
| `Support/AppExtensions.swift` | 46 | Supp | **Only** `NSImage.floppyDiskIcon` (per source verification — no NSColor/String/Double extensions exist) | 02 |
| `Views/Components/CircularProgressDownloadButton.swift` | 198 | UI | Radial download-progress button (ReactiveIconButton subclass) | 06 |
| `Views/Components/GlassSearchField.swift` | 237 | UI | Vertically-centered glass `NSSearchField` + cell | 06 |
| `Views/Components/HeaderView.swift` | 122 | UI | Browser-mode toolbar (back/forward/reload/home/account/mode/quit) | 06 |
| `Views/Components/LiquidGlassSegmentedSlider.swift` | 310 | UI | Liquid segmented control (`LiquidSegmentedControl`, `SettingsTone`) | 06 |
| `Views/Components/NativeCapsuleToggleView.swift` | 69 | UI | Capsule switch control | 06 |
| `Views/Components/ReactiveIconButton.swift` | 250 | UI | SF Symbol button with hover/spring animations | 06 |
| `Views/Components/WaveformProgressView.swift` | 324 | UI | Interactive waveform seek bar with scrub tooltip + timestamps | 06 |
| `Views/Libraries/OfflineLibraryView.swift` | 941 | UI | Local-track browser: search/sort/play/import; `OfflineTableView`, cell | 06 |
| `Views/Libraries/OfflineOverlayView.swift` | 117 | UI | "Working offline" banner | 06 |
| `Views/Libraries/PlaylistLibraryView.swift` | 3408 | UI | Playlist/liked/downloads/history library UI; 5 modes; ~55 context-menu items | 06 |
| `Views/Libraries/SwipeToDeleteContainerView.swift` | 644 | UI | Swipe-to-delete row container (coordinator + card) | 06 |
| `Views/Player/DynamicIslandPlayerView/Core.swift` | 1176 | UI | Dynamic Island pill player: layout, controls, drawer, waveform, themes, keyboard | 05 |
| `Views/Player/DynamicIslandPlayerView/SettingsPanel.swift` | 3546 | UI | Expandable settings drawer: playlists, downloads, history, likes, themes, prefs | 05 |
| `Views/Player/DynamicIslandPlayerView/ArtworkTheme.swift` | 227 | UI | Artwork loading + ambient dominant-color extraction + glow updates | 05 |
| `Views/Windows/CenteredMenuBarLyricsWindowController.swift` | 282 | UI | Menu-bar-centered HUD: synced lyrics lines + status toasts | 05 |
| `Views/Windows/LaunchAnimationController.swift` | 173 | UI | Startup branding animation controller | 05 |
| `Views/Windows/LaunchOverlayView.swift` | 152 | UI | SwiftUI launch overlay (Siri-edge ribbon style) | 05 |
| `Views/Windows/NativeGestureTutorialWindowController.swift` | 85 | UI | Trackpad gesture tutorial window (loads `trackpad.html`) | 05 |
| `Web/URLFilter.swift` | 34 | Web | Link/text detection heuristic (content blocking lives in YTMWebView) | 02 |
| `Web/YTMWebView.swift` | 602 | Web | `WKWebView` container: config, UA, scripts, content-rule list `YTMBlockRules`, crash recovery, offline overlay | 02 |

## Root / config / docs — 8+ files

| File | Purpose |
| :--- | :--- |
| `Package.swift` | SPM manifest (Swift 5.9, macOS 13, executable target, no deps) |
| `build_app.sh` | Full build pipeline (see `11_CONFIGURATION/BUILD_CONFIGURATION.md`) |
| `.gitignore` | Ignores `.build/`, `.DS_Store`, secret files, `dev/` |
| `README.md` | Product README |
| `AGENTS.md` | Agent guidance (build commands, source layout, conventions) |
| `AGY.md` | Agent context + architecture manual + session log |
| `CHANGELOG.md` | Changelog (formerly PROJECT_CHANGES_LOG.md) |
| `LICENSE` | MIT license |
| `docs/` (13 files) | Derived analysis reports & notes (reports: CODEBASE_STRUCTURE_REPORT, CODING_AGENT_FIX_REPORT, PLAYLIST_ARCHITECTURE_REPORT, QUEUE_BLUEPRINT, Playbackreport, AUDIO_ONLY_NOT_AVAILABLE_DIAGNOSTIC, codebase_efficiency_technical_debt_audit, report/latestreport; notes: BLACKBOOK, todolist) |
| `dev/` (15 files) | Git-ignored development tooling (GPU monitoring, diagnostics, tree tools, screenshots) |

## Cross-reference: work packages in `99_APPENDIX/RAW_DISCOVERY_NOTES/`

| # | File | Covers |
| :--- | :--- | :--- |
| 01 | `01_CORE_LAYER.md` | App/, Core/ (MainViewController, DisplayManager, NowPlayingManager/, StatusItemManager/) |
| 02 | `02_AUDIO_WEB_INPUT.md` | Audio/, Web/, Input/, Support/ |
| 03 | `03_DATA_MANAGERS.md` | LocalDatabaseManager, LocalLibraryManager, PlaylistManager, DownloadManager |
| 04 | `04_LYRICS_MANAGERS_MODELS.md` | Lyrics, parsers, history, likes, RPC, notifications, network, artwork, all Models/ |
| 05 | `05_PLAYER_WINDOWS_UI.md` | DynamicIslandPlayerView/*, Views/Windows/* |
| 06 | `06_LIBRARIES_COMPONENTS_UI.md` | Views/Libraries/*, Views/Components/* |