# AGY.md — Mooziac Agent Context & Work Tracker

This document serves as the persistent single source of truth for AI agents (AGY) working on the **Mooziac** codebase. It provides an in-depth breakdown of `Sources/Mooziac/`, the system architecture, component relationships, build conventions, and an active log of **what was worked on** and **what must be updated next**.

---

## 📌 1. Project Overview

**Mooziac** is a high-performance native macOS music application designed as a hybrid menu bar & floating Dynamic Island player. It bridges:
1. **Online Playback**: A specialized WebKit (`WKWebView`) container running YouTube Music with custom ad/telemetry filtering, CSS injections, and bi-directional JavaScript observation.
2. **Offline Playback**: A native `AVFoundation` engine (`NativeAudioPlayer`) playing local audio files (`mp3`, `m4a`, `flac`, `wav`, `aac`, `ogg`, `opus`) from `~/Music/Mooziac` and `~/Library/Application Support/Mooziac/Offline`.
3. **Hardware & Input Control**: Edge trackpad volume gestures (0.01mm touch stream via private Multitouch framework), global keyboard shortcuts, and menu bar scroll-wheel actions.
4. **Desktop UI/UX**: Liquid glass floating HUD, dynamic color palette extraction from album art, interactive lyrics overlay, and animated window transitions.

---

## 📂 2. In-Depth `Sources/Mooziac/` Folder Structure

`Sources/Mooziac/` is a single Swift Package Manager target where all subdirectories compile recursively.

```
Sources/Mooziac/
├── App/                # Application lifecycle, delegate, sleep management
├── Audio/              # CoreAudio, AVPlayer, trackpad edge volume engine
├── Core/               # Central view controllers, playback state, status item & panel
├── Input/              # Multitouch gestures, hotkeys, keyboard command handlers
├── Managers/           # Singletons for database, library, playlists, downloads, lyrics, RPC
├── Models/             # Pure Swift data structures, enums, timeline models
├── Support/            # Foundation & AppKit extensions, glassmorphic drawing helpers
├── Views/              # UI components, floating player, libraries, overlays, windows
└── Web/                # WebKit integration, URL filtering, ad blocking, DOM bridge
```

---

### 2.1 `App/` — App Lifecycle & Environment
- [`main.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/App/main.swift): Custom entry point creating `NSApplication.shared`, attaching `AppDelegate`, and invoking `NSApp.run()`.
- [`AppDelegate.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/App/AppDelegate.swift):
  - Sets application activation policy to `.accessory` (no Dock icon, lives in Menu Bar).
  - Cleans legacy settings keys.
  - Initializes background sleep prevention, edge volume engine, audio route monitors, network monitor, Discord RPC, and the main `StatusItemManager`.
  - Sets up native Edit menu (Undo, Redo, Cut, Copy, Paste, Select All).
- [`BackgroundMediaController.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/App/BackgroundMediaController.swift): Uses `IOPMAssertionCreateWithName` with `kIOPMAssertionTypePreventUserIdleSystemSleep` to ensure audio playback does not cut out when displays lock or sleep.

---

### 2.2 `Audio/` — Playback Engines & CoreAudio
- [`NativeAudioPlayer.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Audio/NativeAudioPlayer.swift): Native `AVPlayer` offline player handling local file queues, shuffle arrays, repeat modes (`.off`, `.all`, `.one`), periodic time observation, and playback notifications.
- [`EdgeVolumeEngine.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Audio/EdgeVolumeEngine.swift): Low-level multi-touch trackpad engine. Hooks into raw trackpad touch data to enable smooth sliding on the far right edge of the trackpad to adjust macOS system volume with CoreAudio scalar manipulation and tactile haptic feedback.
- [`AppVolumeManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Audio/AppVolumeManager.swift): Volume bridging between application-level volume controls and macOS system volume.
- [`AudioRouteMonitor.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Audio/AudioRouteMonitor.swift): Listens for audio device disconnections (e.g. unplugging headphones or disconnecting Bluetooth AirPods) to automatically pause playback and prevent sudden blasting through laptop speakers.
- [`ClickSound.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Audio/ClickSound.swift): Plays lightweight system feedback sound effects for subtle UI interactions.

---

### 2.3 `Core/` — Central Controllers & Playback Coordination
- [`MainViewController.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Core/MainViewController.swift): Central container controller hosting:
  - `DynamicIslandPlayerView` (floating player UI).
  - `browserContainerView` wrapping `YTMWebViewContainer` and `HeaderView`.
  - `OfflineLibraryView` and `PlaylistLibraryView`.
  - Search query router (fuzzy matches local tracks in offline mode or executes auto-play JavaScript on YouTube Music in online mode).
  - Window size management and delegate callbacks.
- [`DisplayManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Core/DisplayManager.swift): Screen geometry helper calculating status item placement, multi-monitor coordinates, and safe areas below the macOS camera notch.
- `NowPlayingManager/`:
  - [`NowPlayingManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Core/NowPlayingManager/NowPlayingManager.swift): Central state singleton managing `currentState: PlaybackState`, switching between `.online` and `.offline` modes, observing system sleep/wake, network reachability, and WebContent recovery.
  - [`ObserverBridge.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Core/NowPlayingManager/ObserverBridge.swift): Injects JavaScript into `WKWebView` to continuously track song title, artist, album, artwork, duration, current time, and liked status; synchronizes with `MPNowPlayingInfoCenter` and handles `MPRemoteCommandCenter` media keys.
  - [`PlayerControls.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Core/NowPlayingManager/PlayerControls.swift): Dispatches play/pause, next, previous, seek, volume, like, shuffle, and repeat commands to either WebKit or `NativeAudioPlayer`.
  - [`Queue.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Core/NowPlayingManager/Queue.swift): Queue helper logic.
- `StatusItemManager/`:
  - [`StatusItemManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Core/StatusItemManager/StatusItemManager.swift): Manages the `NSStatusItem` in the macOS menu bar, status bar popover/panel toggle, scroll-wheel volume adjustment over the icon, and drag-and-drop undocking from the menu bar into a floating desktop widget.
  - [`StatusItemPanel.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Core/StatusItemManager/StatusItemPanel.swift): Custom `NSPanel` with transparent background, liquid glass blur, rounded corners, level management (`.floating` / `.normal`), and drag repositioning.
  - [`ContextMenu.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Core/StatusItemManager/ContextMenu.swift): Right-click context menu (Preferences, Reset Position, Restart Web Engine, Quit).

---

### 2.4 `Input/` — User Gestures & Hotkeys
- [`GestureMappingManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Input/GestureMappingManager.swift): Configurable multi-touch gesture interpreter for trackpad corner taps, edge sliders, and multi-finger gestures.
- [`GlobalHotKeyManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Input/GlobalHotKeyManager.swift): Global Cocoa / Carbon key monitor listening for system-wide shortcuts (`Ctrl+Option+Space`, `Cmd+Shift+Space`, Left/Right arrows, `L` to like).
- [`KeyboardCommandHandler.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Input/KeyboardCommandHandler.swift): Intercepts keyboard events within UI controls for quick escape, enter, and navigation shortcuts.

---

### 2.5 `Managers/` — Services & Data Persistence
- [`LocalDatabaseManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/LocalDatabaseManager.swift): SQLite / local persistent store managing playlists, tracks, history, likes, and custom metadata tags.
- [`LocalLibraryManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/LocalLibraryManager.swift): Thread-safe scanner for `~/Music/Mooziac` and app offline storage; extracts audio ID3 tags (artist, album, title, embedded artwork), coalesces scan requests, and manages liked status.
- [`PlaylistManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/PlaylistManager.swift): Manages custom user playlists, track associations, reordering, and playback triggers.
- [`DownloadManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/DownloadManager.swift): Downloads audio streams and metadata for offline listening.
- [`HistoryManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/HistoryManager.swift): Tracks recently played songs with timestamps and duplicate prevention.
- [`LyricsManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/LyricsManager.swift): Fetches synced `.lrc` and plain-text lyrics from online sources or local files.
- [`SyncedLyricsParser.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/SyncedLyricsParser.swift): High-speed parser for timestamped `[mm:ss.xx]` lyrics lines for real-time karaoke-style display.
- [`DiscordRPCManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/DiscordRPCManager.swift): IPC socket client connecting to local Discord client to display rich presence ("Playing [Track] by [Artist]").
- [`NetworkMonitor.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/NetworkMonitor.swift): `NWPathMonitor` wrapper providing real-time reachability updates to trigger seamless fallback to offline library when internet is disconnected.
- [`TrackNotificationManager.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/TrackNotificationManager.swift): Native macOS banner notifications on track change with artwork.
- [`AppArtworkHelper.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Managers/AppArtworkHelper.swift): Caches artwork images, creates thumbnails, and extracts dominant/accent color palettes for glassmorphic dynamic theming.

---

### 2.6 `Models/` — Data Structures
- [`LocalTrack.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/LocalTrack.swift): Model for local audio files (id, title, artist, album, duration, fileURL, artwork, lrcURL, isLiked, dateAdded, ytVideoId).
- [`PlaybackState.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/PlaybackState.swift): Snapshot of current playback (title, artist, album, artwork, duration, currentTime, isPlaying, isLiked, volume, repeatMode, isShuffle).
- [`PlaybackEngineMode.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/PlaybackEngineMode.swift): `.online` (WebKit) vs `.offline` (AVPlayer).
- [`PlayerDesign.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/PlayerDesign.swift): Visual theme styling modes (Liquid Glass, Dynamic Island, Minimalist, Cyberpunk, OLED Dark, etc.).
- [`ProgressStyle.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/ProgressStyle.swift): Scrub bar presentation styles (Waveform, Liquid Capsule, Minimal Line).
- [`RepeatMode.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/RepeatMode.swift): `.off`, `.all`, `.one`.
- [`GestureMappingModels.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/GestureMappingModels.swift): Data structures defining trackpad touch regions, gesture triggers, and mapped player actions.
- [`LaunchAnimationTimeline.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Models/LaunchAnimationTimeline.swift): Timeline definitions for app launch transitions.

---

### 2.7 `Views/` — User Interface
- **Components/**:
  - [`CircularProgressDownloadButton.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Components/CircularProgressDownloadButton.swift): Radial progress ring button indicating download progress.
  - [`GlassSearchField.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Components/GlassSearchField.swift): Glass-styled search bar with search/clear icons.
  - [`HeaderView.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Components/HeaderView.swift): Top toolbar for Web browser mode (Back, Forward, Reload, Home, Account, Player mode, Quit).
  - [`LiquidGlassSegmentedSlider.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Components/LiquidGlassSegmentedSlider.swift): Custom fluid glass segmented control for theme/tab switching.
  - [`NativeCapsuleToggleView.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Components/NativeCapsuleToggleView.swift): macOS capsule switch toggle with spring animations.
  - [`ReactiveIconButton.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Components/ReactiveIconButton.swift): Button with responsive hover effects, scale bouncing, and SF Symbols.
  - [`WaveformProgressView.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Components/WaveformProgressView.swift): Interactive audio seek bar with live scrub tooltip and elapsed/remaining timestamps.
- **Libraries/**:
  - [`OfflineLibraryView.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Libraries/OfflineLibraryView.swift): Full-featured local track browser (search, sorting, playback trigger, import files).
  - [`OfflineOverlayView.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Libraries/OfflineOverlayView.swift): Visual banner alerting when working offline.
  - [`PlaylistLibraryView.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Libraries/PlaylistLibraryView.swift): Comprehensive playlist management UI (create, delete, add song, play playlist).
  - [`SwipeToDeleteContainerView.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Libraries/SwipeToDeleteContainerView.swift): Interactive swipe-to-delete container for track list items.
- **Player/DynamicIslandPlayerView/**:
  - [`Core.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Player/DynamicIslandPlayerView/Core.swift): Main Dynamic Island pill player view. Supports compact mode, expanded controls, seek bar, play/pause/prev/next/repeat/shuffle/like buttons, and animated drawer expansion.
  - [`ArtworkTheme.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Player/DynamicIslandPlayerView/ArtworkTheme.swift): Real-time color analysis from current artwork; dynamically tints backgrounds, borders, and button highlights.
  - [`SettingsPanel.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Player/DynamicIslandPlayerView/SettingsPanel.swift): Expandable settings panel embedded in the player (themes, preferences, playlists, download management, history).
- **Windows/**:
  - [`CenteredMenuBarLyricsWindowController.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Windows/CenteredMenuBarLyricsWindowController.swift): Floating HUD window positioned at top screen center for displaying real-time synced karaoke lyrics and status toast messages.
  - [`LaunchAnimationController.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Windows/LaunchAnimationController.swift) & [`LaunchOverlayView.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Windows/LaunchOverlayView.swift): Smooth startup branding animation.
  - [`NativeGestureTutorialWindowController.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Views/Windows/NativeGestureTutorialWindowController.swift): Interactive tutorial window showing users how trackpad edge volume and gestures work.

---

### 2.8 `Web/` — WebKit & Ad/Content Blocking
- [`YTMWebView.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Web/YTMWebView.swift): `WKWebView` wrapper configured with custom User-Agent, media autoplay policies, WebContent termination crash auto-recovery, and CSS injection to hide YouTube Music header/footer clutter in mini-player mode.
- [`URLFilter.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Web/URLFilter.swift): WebKit content rule lists blocking Google ad tracking, telemetry popups, and non-music navigation.

---

### 2.9 `Support/` — Shared Helpers
- [`AppExtensions.swift`](file:///Users/harshshirke/local/projects/mp3kal/Sources/Mooziac/Support/AppExtensions.swift): Extensions for `NSColor` (hex values, dynamic luminance), `NSImage` (resizing, tinting, rounded corners), `NSView` (shaking animations, corner radius), `String` (fuzzy search), and `Double` (time formatting).

---

## 🛠 3. Build & Deployment Pipeline

```bash
swift build            # Debug compile
swift build -c release # Release compile
./build_app.sh         # Full pipeline: Release compile -> Bundle into Mooziac.app -> Copy Resources -> Ad-hoc sign -> Launch
```

> [!IMPORTANT]
> **Runtime Assets Rule**: All runtime assets (images, icons, HTML templates) live in [`Resources/`](file:///Users/harshshirke/local/projects/mp3kal/Resources). `build_app.sh` copies assets strictly from `Resources/`. `trackpad.html` and `macbook_panel.jpg` are coupled and must be kept together.

---

## 🔄 4. Active Work & Session Tracker

*This section MUST be updated during and after every session.*

### 4.1 Current Status
- **Repository State**: Fully completed Phase 1, Phase 2, and Phase 3 database, memory cache unification, timer rendering, and adaptive IPC optimizations. Verified full build, universal binary linking, codesigning, DMG/ZIP distribution packaging, and launch via `./build_app.sh`.
- **Active Version**: 0.1.0
- **Primary Focus**: Optimization suite verified clean and stable with zero regressions.

---

### 4.2 Work Log (Chronological)

| Date | Session Summary | Key Files Touched / Referenced | Outcome |
| :--- | :--- | :--- | :--- |
| **2026-08-19** | Initial full-codebase deep audit & creation of `AGY.md` | `Sources/Mooziac/**`, `AGENTS.md`, `Package.swift`, `build_app.sh` | Mapped all 76 files across 9 subfolders in `Sources/Mooziac/`. Established persistent work tracker and architectural manual. |
| **2026-08-19** | Liquid Glass (Control Center style) Color Theme Feasibility Analysis | `PlayerDesign.swift`, `ArtworkTheme.swift`, `StatusItemPanel.swift`, `Core.swift` | Analyzed feasibility: player architecture natively supports Control Center liquid glass backdrop & artwork-reactive gradient mesh tinting without altering existing controls. Added to backlog. |
| **2026-08-19** | **Full-App Liquid Glass Design Theme Implementation** | `LiquidGlassTheme.swift`, `PlayerDesign.swift`, `Core.swift`, `ArtworkTheme.swift`, `SettingsPanel.swift`, `OfflineLibraryView.swift`, `PlaylistLibraryView.swift`, `HeaderView.swift`, `CenteredMenuBarLyricsWindowController.swift`, `GlassSearchField.swift`, `CircularProgressDownloadButton.swift`, `ReactiveIconButton.swift` | Implemented frosted `NSVisualEffectView` + dynamic artwork gradient mesh theme engine (`LiquidGlassBackdropView`). Wired theme tokens across Dynamic Island player, all Settings tabs, Offline Library, Playlist Library, Glass Search Field, Header Bar, Lyrics HUD capsule, and reactive buttons. Verified full build with `swift build`. |
| **2026-08-19** | **Rollback of Liquid Glass Theme Changes** | All touched files across `Sources/Mooziac/` | Successfully reverted all Liquid Glass additions across the codebase. Restored original theme suite (`.adaptive`, `.darkMode`, `.glassMode`), re-aligned all component layouts and color logic, and verified build with `swift build` and `./build_app.sh`. |
| **2026-08-19** | **Playback of Liked Songs, Downloads & Cross-Library Playlist Additions with Right-Click Context Menus** | `PlaylistManager.swift`, `PlaylistLibraryView.swift`, `SettingsPanel.swift` | Added `appendTrack`, `appendHistoryItem`, and `appendLikedSong` to `PlaylistManager`. Added Liked Songs tab/mode with native cell rendering, offline/online fallback playback, swipe actions, and search filtering in `PlaylistLibraryView`. Implemented rich right-click context menus (`Play Track`, `Play Next`, `Add to Queue`, `Add to Playlist` [with submenu of playlists + `+ New Playlist…`], `Like/Unlike`, `Download Track`, `Show in Finder`, `Remove/Delete`) across `PlaylistLibraryView` and the Dynamic Island drawer (`DownloadRowView`, `DetailItemRowView`, `HistoryRowView`, `LikedSongRowView`). Compiled and launched via `./build_app.sh`. |
| **2026-08-21** | **Distribution binary hardening: symbol stripping** | `build_app.sh`, `mooziac.sh` | Added `strip -x -S` before codesign in both scripts so distributable binaries ship without the symbol table (dist symbols 10,748 → 2,573; app class names 664 → 124). Dev builds keep full symbols; `./build_app.sh` builds, signs (codesign OK), and launches verified. |
| **2026-08-24** | **Interactive Mooziac Agent Wizard & Token-Optimized Mode Prefixes** | `mooziac.sh`, `mooziac_brain/interactive.py`, `mooziac_brain/cli.py`, `AGENTS.md` | Built interactive terminal launcher (`./mooziac.sh` / `./brain prompt`) with auto-brain sync, subsystem picker, Plan vs Build modes, AGY vs OpenCode selection, and automatic clipboard export via `pbcopy`. Wired `[PLAN]` and `[BUILD]` protocol into `AGENTS.md`. |
| **2026-08-24** | **Dynamic Island Player 3-Dots Menu Version Indicator** | `SettingsPanel.swift`, `Core.swift` | Added native version indicator (`Mooziac vX.X.X` via `UpdateManager.shared.currentVersion`) below the Discord status row in the Dynamic Island Player 3-dots preferences menu. Configured auto-adaptive palette theming and adjusted panel height constraint. Verified compilation with `swift build`. |
| **2026-08-25** | **Memory Pressure Handler Fix & Build Recovery** | `Sources/Mooziac/Managers/AppArtworkHelper.swift` | Replaced invalid iOS-only `NSApplication.didReceiveMemoryWarningNotification` observer with `DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)`. Verified full compilation and `./build_app.sh` pipeline execution (universal binary build, ad-hoc signing, DMG/ZIP generation, launch). |
| **2026-08-25** | **Full Phase 1-3 Performance & Memory Optimization Suite** | `LocalDatabaseManager.swift`, `AppArtworkHelper.swift`, `DynamicIslandPlayerView/Core.swift`, `DynamicIslandPlayerView/ArtworkTheme.swift`, `PlaylistLibraryView.swift`, `PlayerControls.swift`, `NowPlayingManager.swift`, `ObserverBridge.swift`, `StatusItemManager.swift` | Unified memory caching across all views into `AppArtworkHelper.shared.memoryCache` (capped at 12MB + dynamic memory pressure auto-purge); updated SQLite corruption recovery PRAGMAs (2MB cache, 16MB mmap); implemented adaptive JS IPC throttling (350ms when panel is active, 1000ms when closed); verified complete release pipeline via `./build_app.sh`. |
| **2026-08-25** | **WebView Video Playback Suppression & Dynamic Album Artwork Overlay** | `Sources/Mooziac/Web/YTMWebView.swift`, `Sources/Mooziac/Core/NowPlayingManager/ObserverBridge.swift` | Suppressed video frame rendering, annotations, and cards via CSS; injected adaptive video downscaling (`setPlaybackQuality('tiny')` / `144p`) to eliminate background decode memory and CPU usage while locking `AUDIO_QUALITY_HIGH`; injected `#mooziac-artwork-overlay` inside `ytmusic-player` to display clean high-res album artwork with rounded corners and drop shadows for signed-out and non-premium users. Verified with `./build_app.sh`. |
| **2026-08-25** | **Native YouTube & YouTube Music Playlist & Track Link Import (Menu Bar Settings)** | `Sources/Mooziac/Managers/YTMClient.swift`, `Sources/Mooziac/Managers/PlaylistManager.swift`, `Sources/Mooziac/Core/StatusItemManager/ContextMenu.swift` | Implemented 100% native link importing for both playlists (`list=PL...`) and individual song links (`watch?v=...`, `youtu.be/...`). Single song links automatically fetch metadata via `/player` and insert into "Imported Tracks" playlist. Placed cleanly in menu bar right-click `Settings` -> `Import Playlist from Link…` with clipboard auto-fill. Verified with `./build_app.sh`. |
| **2026-08-26** | **Trackpad Gesture Settings Dummy Cleanup & Brain Graph Hardening** | `GestureMappingModels.swift`, `GestureMappingManager.swift`, `relationship_graph.py` | Removed all dummy gesture triggers (3-finger swipes, pinches, edge swipes) and dummy actions (`showQueue`, `toggleFullscreen`). Retained only the 4 verified working corner taps and 12 fully functional playback/system actions in Settings and Context Menu. Hardened Brain graph persistence with atomic writes and auto-recovery. Verified compilation with `swift build`. |
| **2026-08-26** | **4th Player Theme: Monochromatic Apple Liquid Glass & High-Contrast Toggles (`.native`)** | `PlayerDesign.swift`, `Core.swift`, `ArtworkTheme.swift`, `SettingsPanel.swift`, `NativeCapsuleToggleView.swift`, `NativeCapsuleStepToggleView.swift` | Enhanced `.native` theme to match Apple's native monochromatic Control Center liquid glass: eliminated all neon blues; active switches & sliders render as solid Apple pure white (`#FFFFFF`) with deep graphite knobs (`#1F1F1F`), inactive switches render as translucent glass reservoirs (`rgba(255,255,255,0.16)`) with white knobs, and waveform progress / controls use pure Apple white glass styling. Verified with `./build_app.sh`. |
| **2026-08-26** | **Full-Screen Stage Removal & Clean Menu Bar Isolation** | `Core.swift`, `ContextMenu.swift`, `FullScreenPlayerWindowController.swift` (deleted) | Completely removed experimental full-screen standby window controller, shortcuts, and context menu items as requested. Kept Mooziac strictly focused on its lightweight menu bar Dynamic Island architecture. Verified with `./build_app.sh`. |
| **2026-08-26** | **Equalizer & Sleep Timer Full Cleanup & Core Pipeline Hardening** | `EqualizerManager.swift` (deleted), `SleepTimerManager.swift` (deleted), `ContextMenu.swift`, `SettingsPanel.swift`, `Core.swift`, `YTMWebView.swift` | Cleanly removed the Equalizer and Sleep Timer components to keep Mooziac strictly focused on its lightweight menu bar Dynamic Island architecture without non-functional Web Audio CORS limitations or extra background timers. Preferences drawer and Right-Click Context Menu remain fast and uncluttered. Verified with `./build_app.sh`. |
| **2026-08-26** | **Handoff Removal & Bloat-Free Core Pipeline** | `HandoffManager.swift` (deleted), `PlayerControls.swift`, `build_app.sh` | Removed experimental Apple Handoff code to keep Mooziac strictly focused on its lightweight menu bar architecture without non-functional macOS/iOS sandbox limitations. Verified with `./build_app.sh`. |
| **2026-08-26** | **Single Unified WebKit Media Session for Control Center** | `PlayerControls.swift` | Eliminated the secondary manual `MPNowPlayingInfoCenter` broadcast during online playback. macOS Control Center now displays exactly 1 unified YouTube media player with native play, pause, and skip controls. Verified with `./build_app.sh`. |
| **2026-08-26** | **Mooziac v0.1.0 Official GitHub Release, Source Push & Website Deployment** | `release.sh`, `build_app.sh`, `Github/**`, `UpdateManager.swift`, `www/index.html`, `www/push.sh` | Updated versioning to `0.1.0` (Build 1). Synchronized all active Swift sources, views, components, and build scripts into `Github/`. Committed and pushed changes to GitHub `origin/main` (`3035aba`), updated git tag `v0.1.0`, published release assets with `--latest`, and deployed updated website (`www/index.html`) to live production VPS (`mooziac.threeten.site`) via `www/push.sh`. |
| **2026-08-26** | **macOS First-Time Launch & Gatekeeper Approval Guide Across All Touchpoints** | `README.md`, `Github/README.md`, `release.sh`, `www/index.html`, `Github/docs/index.html` | Added clear, user-friendly instructions for macOS Gatekeeper verification (Clicking [Open Anyway] or running `xattr -cr /Applications/Mooziac.app`). Deployed to live website and pushed commit `bb2bd0b` to GitHub. |
| **2026-08-26** | **Mooziac Brain Publication-Grade PDF Compilation to Desktop** | `scripts/build_brain_pdf.py`, `.mooziac-brain/**`, `SYSTEM_DESIGN.md` | Compiled all 15 Mooziac Brain knowledge modules, architecture blueprints, subsystem maps, and work logs into a formatted publication PDF with Table of Contents and section numbering. Exported directly to `~/Desktop/Mooziac_Brain_System_Design.pdf`. |
| **2026-08-26** | **Release Pipeline Overhaul (Auto-Increment, GitHub Sync, Source Zip & Asset Publishing)** | `release.sh` | Upgraded `release.sh` to automatically detect & bump version numbers by point/patch (`0.1.0` ➔ `0.1.1`), fetch remote GitHub state, sync all project sources (`Sources/Mooziac`), resources, docs, entitlements, and package configs into `Github/`, build production binaries via `build_app.sh`, archive a clean source code zip, commit and push changes to GitHub repository, and publish GitHub releases with DMG, App ZIP, and Source Code ZIP with SHA-256 checksums. |
| **2026-08-26** | **Website & GitHub Download Link Verification & VPS Deployment** | `www/index.html`, `Github/docs/index.html`, `www/push.sh` | Verified GitHub release `v1.0.1` download URLs and HTTP 302 redirection. Updated schema `softwareVersion` to `1.0.1` in `www/index.html` and `Github/docs/index.html`. Linked footer anchor tags (`Release Notes`, `Privacy`, `Support`) directly to GitHub repository URLs. Successfully synced all website assets to live VPS via `www/push.sh`. |
| **2026-08-26** | **GitHub README Restoration & Hero Assets Sync (`Animals.png`)** | `Resources/Animals.png`, `Github/Resources/Animals.png`, `README.md`, `Github/README.md` | Restored missing player preview assets (`Animals.png`, `Animals 2.png`, `Animals 3.png`) into `Resources/` and `Github/Resources/`. Re-integrated the complete header banner with `launch_transparent.png`, live version/platform badges, fast download action links, and the full-width centered `Animals.png` interface preview. Committed and pushed commit `52829e7` directly to GitHub `origin/main`. |
| **2026-08-26** | **Mooziac Studio Telemetry & SQLite Database Cockpit Fix** | `SQLiteInspector.swift`, `TelemetryMonitor.swift`, `StudioState.swift`, `TelemetryDBView.swift`, `generator.py` | Fixed SQLiteInspector looking for incorrect `mooziac.db` by resolving real `library.sqlite3` database (and fallbacks). Added dynamic database filename & file size indicators, `Reveal DB` Finder button, preserved natural table column ordering for sample records, and hardened `TelemetryMonitor` process detection with `NSWorkspace` fallback. Auto-selects active tables and streams live updates seamlessly. |
| **2026-08-26** | **Zero-Overhead Live CPU, RAM, GPU & Disk Telemetry Engine** | `TelemetryMonitor.swift`, `StudioState.swift`, `TelemetryDBView.swift`, `ColorTheme.swift` | Replaced legacy `ps` subprocess pipes with zero-overhead Mach/Darwin kernel APIs (`proc_pid_rusage`, `proc_pidinfo`) and Apple Silicon IOKit (`IOAccelerator`). Displays live CPU %, RAM resident & physical footprint, hardware GPU utilization %, live Disk Read/Write MB throughput, app storage footprint, and active threads in a 6-card dashboard updated every 1.5s. |
| **2026-08-26** | **Full Mooziac & WebKit Process Tree Resource Aggregation** | `TelemetryMonitor.swift`, `TelemetryDBView.swift` | Aggregated total ecosystem consumption across the Host App, WebKit WebContent (`com.apple.WebKit.WebContent`), WebKit GPU (`com.apple.WebKit.GPU`), and WebKit Networking (`com.apple.WebKit.Networking`). Added total combined RAM (500+ MB), combined CPU, combined storage (App + WebKit + Offline + DB), and an interactive live process tree breakdown strip in Studio. |
| **2026-08-26** | **Website GitHub Repository Integration with Official SVG Logo** | `www/index.html`, `www/css/landing.css`, `Github/docs/index.html`, `www/push.sh` | Integrated official GitHub vector SVG logo buttons and repository links directly alongside the download buttons in the Hero action cluster, the `#download` section (`Download for Mac` + `GitHub Repo`), and the top navigation bar (`nav-links`). Pushed live updates to production VPS (`mooziac.threeten.site`). |



---

### 4.3 What We Have to Update Next (Roadmap & Backlog)

The following items are queued for future tasks:

1. **Theme Customization & Experiments (Backlog)**:
   - Revisit Control Center style glass effects when desired with isolated staging/preview.
2. **Offline Mode Polish**:
   - Verify album artwork caching resilience for large local audio libraries.
   - Improve fuzzy search scoring in `MainViewController.findBestLocalTrack` for acronyms or non-Latin track names.
3. **WebKit Performance & Memory Optimization**:
   - Review memory footprint during long background YouTube Music playback sessions.
   - Ensure `WKUserContentController` message handlers do not leak references on repeated web reloads.
4. **Trackpad Edge Volume Refinements**:
   - Verify sensitivity across diverse MacBook trackpad physical dimensions.
   - Ensure full compatibility with external Magic Trackpad devices.
5. **Lyrics Window Enhancement**:
   - Enhance smooth auto-scroll animation when transitions occur in `CenteredMenuBarLyricsWindowController`.
   - Add customizable font sizing and opacity slider in preferences.

---

## 📋 5. Agent Instructions & Execution Rules

Whenever you work on this codebase in future turns:
1. **Always build with `./build_app.sh`**: At the end of every task or feature implementation, run `./build_app.sh` directly to compile, assemble the `.app` bundle, sign, and launch.
2. **Autonomous Function Edits**: Do not ask for confirmation on every internal function or codebase change. Act decisively and autonomously. Only ask the user when external input, credentials, or destructive actions outside the codebase are required.
3. **Check this file (`AGY.md`) first** to understand current state and pending tasks.
4. **Update Section 4 (Active Work & Session Tracker)**:
   - Add a row to the **Work Log** describing what was done.
   - Update **Current Status**.
   - Update / check off items in **What We Have to Update Next**.

