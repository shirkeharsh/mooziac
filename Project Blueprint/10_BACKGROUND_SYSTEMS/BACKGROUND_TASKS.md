# Background Tasks

Long-running, non-UI work in Mooziac.

## Task inventory

| Task | Owner | Triggers | Runs on | Lifecycle |
| :--- | :--- | :--- | :--- | :--- |
| WebView playback engine | `YTMWebView` (WebKit) | app launch / restore | WebContent process | app lifetime |
| Playback time observer | `NativeAudioPlayer` | offline playback | main (0.25 s) | per track |
| Lyrics HUD updates | `CenteredMenuBarLyricsWindowController` | lyrics window open | main (0.1 s timer) | while visible |
| Download queue | `DownloadManager` | user/auto queue | subprocesses + main | jobs |
| History recording | `HistoryManager` | track plays | dbQueue | per track |
| Library scanning | `LocalLibraryManager` | startup + manual | background queue | per scan |
| Discord presence | `DiscordRPCManager` | state changes | socket worker | app lifetime |
| Network monitoring | `NetworkMonitor` | app launch | NWPathMonitor (background) | app lifetime |
| Artwork generation | `AppArtworkHelper` | artwork requested | ioQueue (concurrent) | per request |
| Auto-download playlists | `PlaylistManager` (plan) | playlist marked auto | download jobs | per playlist |
| Engine-mode restore | `NowPlayingManager` | network flips | main | transient |
| Screen-lock pause/resume | `NowPlayingManager`, `AudioRouteMonitor`, `EdgeVolumeEngine` | system events | main | transient |

## Concurrency model

| Domain | Dispatch queue |
| :--- | :--- |
| DB | `dbQueue` (serial, `.userInitiated`) — history ops; FULLMUTEX covers others |
| Artwork | `ioQueue` (`.concurrent`) — race risk on same key (see risks) |
| Downloads | subprocess + main completions |
| UI state | main thread |
| Network | URLSession + NWPathMonitor (background) |

## Downloads detail

- Queue: `tasks: [DownloadTask]`; `DownloadTask` = url, title, artist, status, progress.
- Auto-download playlist plan: `PlaylistDownloadPlan` (per playlist settings).
- Progress posted via `Mooziac_DownloadProgress` (with progress object); queue changes via `Mooziac_DownloadQueueChanged`.
- Stale downloads cleaned at startup (`cleanupStaleDownloads`).

## Startup tasks (order, from `AppDelegate`)

1. `initializeDefaultSettings` (defaults seeding, `YTM_hasInitializedDefaultSettingsV2`).
2. Configure system services (volume manager, hotkeys, network monitor).
3. Create `MainViewController` + status item; build panel.
4. Load webview (restore session).
5. Scan offline library; open DB (corruption recover path).
6. Discord RPC init; launch notification permission.

## Shutdown tasks

- None explicit for background tasks; download queue is not persisted (in-flight jobs lost on quit — see risks).
- See `13_WORKFLOWS/APP_SHUTDOWN.md`.

## Related

- `10_BACKGROUND_SYSTEMS/TIMERS.md`, `OBSERVERS.md`, `13_WORKFLOWS/APP_STARTUP.md`.