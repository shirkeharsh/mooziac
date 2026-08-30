# System Architecture

High-level view of the Mooziac runtime, derived from source analysis. See `14_DIAGRAMS/ARCHITECTURE.md` for ASCII diagrams.

## The big picture

Mooziac is a **single-process, single-module Swift/AppKit app** with no network backend of its own. It is a *client* to YouTube Music (web), LRCLib/Lyrics.ovh (lyrics), Discord (RPC), and a pair of local CLI tools (`yt-dlp`, `ffmpeg`).

```
┌────────────────────────────────────────────────────────────────────┐
│                        Mooziac process (app)                        │
│                                                                    │
│  ┌─────────────────────────── Core / state ─────────────────────┐  │
│  │   NowPlayingManager (PlaybackState, engineMode, observers)   │  │
│  │        ▲                  ▲                 ▲                 │  │
│  │        │                  │                 │                 │  │
│  │ ┌──────┴─────┐    ┌───────┴──────┐   ┌───────┴──────┐         │  │
│  │ │ WebKit engine│  │ AVPlayer engine│  │ Input layer   │         │  │
│  │ │ YTMWebView   │  │ NativeAudioPlayer│ │ gestures/hotkeys│       │  │
│  │ │ ObserverBridge│  └───────┬──────┘   └───────┬──────┘         │  │
│  │ └──────┬──────┘            │                   │               │  │
│  └────────┼───────────────────┼───────────────────┼───────────────┘  │
│           │                   │                   │                  │
│  ┌────────▼───────────────────▼───────────────────▼──────────────┐   │
│  │                  Service layer (Managers/)                     │   │
│  │  DB · Library scan · Playlists · Downloads · Lyrics · History  │   │
│  │  Likes · Discord · Notifications · Network · Artwork · RPC     │   │
│  └────────┬───────────────────┬───────────────────┬──────────────┘   │
│           │                   │                   │                  │
│  ┌────────▼─────────┐ ┌───────▼──────┐  ┌─────────▼────────┐        │
│  │ UI layer (Views/)│ │ Storage layer│  │ External services │        │
│  │ Player · Library │ │ SQLite · caches│ │ YTM · LRCLib ·   │        │
│  │ HUD · Menu bar   │ │ UserDefaults │  │ Discord · yt-dlp │        │
│  └──────────────────┘ └──────────────┘  └──────────────────┘        │
└────────────────────────────────────────────────────────────────────┘
```

## Key architectural decisions

1. **Single SPM executable target** with recursive compilation; zero third-party packages. All "dependencies" are Apple frameworks + private-framework `dlopen` (Multitouch) + CLI subprocesses (`yt-dlp`, `ffmpeg`).
2. **Two playback engines, one state owner.** `NowPlayingManager` is the single owner of `PlaybackState` and `engineMode` (`.online`/`.offline`). `PlayerControls` dispatches commands to whichever engine is active. `ObserverBridge` is the JS bridge for online mode; `NativeAudioPlayer` is the offline engine.
3. **Singleton-heavy architecture.** `NowPlayingManager`, `LocalDatabaseManager`, `LocalLibraryManager`, `PlaylistManager`, `DownloadManager`, `LyricsManager`, `HistoryManager`, `LikedSongsManager`, `DiscordRPCManager`, `NetworkMonitor`, `AudioRouteMonitor`, `EdgeVolumeEngine`, `AppVolumeManager`, `BackgroundMediaController`, `DisplayManager`, `StatusItemManager`, `LaunchAnimationController`, `AppArtworkHelper`, `SyncedLyricsParser`, `ClickSound` all expose `static let shared` (or are used as shared singletons). This is the project's central coupling mechanism — see `15_ISSUES_AND_RISKS` for the consequences.
4. **Notification-driven decoupling between managers and UI.** `NotificationCenter` names like `Mooziac_LibraryUpdated`, `Mooziac_DownloadProgress`, `YTM_playerDesignChanged`, `ProgressStyleDidChange`, `NetworkMonitorStatusChanged` let views update without direct references.
5. **JS-injection bridge as the online control plane.** The web player is driven by injected JavaScript (`evaluateJavaScript`) against YouTube Music's Polymer DOM. This is powerful but fragile (see risks).
6. **SQLite as local source of truth** for tracks, playlists, history, likes; UserDefaults for settings/session; filesystem caches for lyrics/artwork; filesystem for offline downloads.

## Process-ownership map

| Component | Process | Threading |
| :--- | :--- | :--- |
| All UI | main app process | main thread |
| `WKWebView` + JS bridge | app process (WebContent is a separate WebKit process) | callbacks arrive on main |
| `NativeAudioPlayer` | app process | AVPlayer callbacks; periodic observer on main |
| `EdgeVolumeEngine` | app process | Multitouch callback thread → hops to main |
| `DownloadManager` | app process | serial `workQueue` + `Pipe` readability threads |
| `LocalDatabaseManager` | app process | SQLite FULLMUTEX; history ops on `dbQueue` |
| `DiscordRPCManager` | app process | utility queue + socket read |
| `yt-dlp` / `ffmpeg` | **separate subprocesses** | spawned via `Process` |
| WebContent (YT Music page) | **WebKit's own process** | — |

## Trust boundaries

- YouTube Music DOM & JS contract (fragile, third-party).
- WebKit cookie store holds Google auth (never read as secrets — only cookie *names* are inspected for sign-in detection).
- Discord IPC socket (local).
- `yt-dlp` invocations with user-supplied titles/video IDs.
- Private Multitouch framework ABI.

## Runtime lifecycle summary

1. `main.swift` → `NSApplication` → `AppDelegate`.
2. `applicationDidFinishLaunching`: accessory activation → purge legacy keys → sleep prevention → EdgeVolumeEngine → AudioRouteMonitor → NetworkMonitor → Discord RPC → StatusItemManager → launch animation.
3. User opens player (status item), searches, plays; engines/state/UI react.
4. `applicationWillTerminate`: stop sleep prevention.