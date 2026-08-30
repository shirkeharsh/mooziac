# Application Layers

Mooziac is organized into logical layers. This document maps the folder structure to responsibilities and shows the direction of dependencies. Verified from source.

## Layer stack

```
┌────────────────────────────────────────────────────────────────┐
│ 1. ENTRY / LIFECYCLE            App/ (main, AppDelegate,        │
│                                  BackgroundMediaController)      │
├────────────────────────────────────────────────────────────────┤
│ 2. UI LAYER                     Views/ (Player, Libraries,      │
│                                  Components, Windows)            │
│    + Menu-bar shell             Core/StatusItemManager/          │
├────────────────────────────────────────────────────────────────┤
│ 3. CONTROLLER / PRESENTER       Core/MainViewController,        │
│                                  Core/DisplayManager             │
├────────────────────────────────────────────────────────────────┤
│ 4. STATE & PLAYBACK COORDINATION Core/NowPlayingManager/         │
│                                  (state, observer bridge,        │
│                                   player controls, queue)        │
├────────────────────────────────────────────────────────────────┤
│ 5. SERVICE LAYER                Managers/ (singletons: DB,       │
│                                  library, playlists, downloads,  │
│                                  lyrics, history, likes, RPC,    │
│                                  notifications, network, artwork) │
├────────────────────────────────────────────────────────────────┤
│ 6. DOMAIN MODELS                Models/ (pure data & enums)      │
├────────────────────────────────────────────────────────────────┤
│ 7. ENGINE / INFRA               Audio/ (AVPlayer, edge volume,   │
│                                  volume mgmt, route monitor,     │
│                                  click sound)                    │
│                                  Web/ (WKWebView, URLFilter)     │
│                                  Input/ (gestures, hotkeys)      │
│                                  Support/ (extensions)           │
└────────────────────────────────────────────────────────────────┘
```

## Layer responsibilities

### 1. Entry / lifecycle (`App/`)
- Boot the app, activate as `.accessory`, configure the minimal menu.
- Start long-running infrastructure: sleep prevention, edge volume, audio route monitor, network monitor, Discord RPC.
- Own `StatusItemManager` instance.
- Purge legacy UserDefaults keys on launch.

### 2. UI layer (`Views/`, `Core/StatusItemManager/`)
- Renders everything the user sees: the Dynamic Island player, the settings drawer, library views, the lyrics HUD, the launch overlay, the gesture tutorial, the menu-bar status item/panel/context menu.
- Converts user actions into delegate calls (e.g. `DynamicIslandPlayerViewDelegate`, `OfflineLibraryViewDelegate`, `PlaylistLibraryViewDelegate`, `HeaderViewDelegate`) or direct manager calls.
- Subscribes to notifications to re-render on state changes.

### 3. Controller/presenter (`Core/`)
- `MainViewController` owns the player/browser/library swap logic and the search router.
- `DisplayManager` resolves screen geometry (notch-safe placement, display IDs).
- `StatusItemManager` owns the menu-bar item, panel toggling, dock↔float transitions, and scroll-volume.

### 4. State & playback coordination (`Core/NowPlayingManager/`)
- `NowPlayingManager`: the canonical `PlaybackState`, engine mode, observer registry, sleep/wake & network-aware auto-pause/resume, WebContent recovery.
- `ObserverBridge`: JS injection + message handling + system Now Playing + media keys + EQ/queue JS.
- `PlayerControls`: command dispatch to JS or `NativeAudioPlayer`.
- `Queue`: queue fetch/sync/reorder/automix.

### 5. Services (`Managers/`)
- Data persistence (`LocalDatabaseManager`), library scanning (`LocalLibraryManager`), playlists (`PlaylistManager`), downloads (`DownloadManager`), lyrics (`LyricsManager` + `SyncedLyricsParser`), history (`HistoryManager`), liked songs (`LikedSongsManager`), Discord (`DiscordRPCManager`), notifications (`TrackNotificationManager`), reachability (`NetworkMonitor`), artwork (`AppArtworkHelper`).

### 6. Models (`Models/`)
- Pure data types: `PlaybackState`, `LocalTrack`, `PlaylistRecord`/etc. (in `LocalDatabaseManager`), enums `RepeatMode`, `PlaybackEngineMode`, `PlayerDesign`, `ProgressStyle`, `GestureType`/`GestureAction`, `LikedSongRecord`, `LaunchAnimationTimeline`.

### 7. Engines & infrastructure (`Audio/`, `Web/`, `Input/`, `Support/`)
- Offline audio engine, volume handling, route monitoring, edge-volume engine, click sounds.
- WebKit container + URL filtering.
- Gesture mapping, global hotkeys, keyboard commands.
- `NSImage` extension (floppyDiskIcon).

## Dependency direction

- Layer 7 (engines) **does not depend on UI** (NativeAudioPlayer has no UI references; EdgeVolumeEngine uses overlays but no Views classes).
- Managers depend on Models + Foundation + (some) AppKit; managers are consumed by controllers, views, and engines.
- Views depend on managers and on `NowPlayingManager` for state.
- `NowPlayingManager` is the hub: everything that cares about "what's playing" goes through it (UI, lyrics, Discord, notifications, media keys).

## Cross-layer exceptions (noted)

- `Models/LocalTrack.swift` imports AppKit (`NSImage`) — documented exception in `AGENTS.md`.
- `BackgroundMediaController` declares `AVAudioEngine`/`AVAudioPlayerNode` but never assigns them (dead scaffold).
- `Support/AppExtensions.swift` is effectively empty of the "extensions" implied by its name (only `NSImage.floppyDiskIcon`).