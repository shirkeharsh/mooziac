# Observers

The observation mechanisms: `NotificationCenter`, KVO, closures, and JS message handlers.

## 1. NotificationCenter (18 names)

| Notification | Posted by | Observed by | Purpose |
| :--- | :--- | :--- | :--- |
| `Mooziac_EngineModeChanged` | NowPlayingManager (3 sites) | — (**no listeners**) | engine switch |
| `Mooziac_LibraryUpdated` | LocalLibraryManager | library views, playlist views | library refresh |
| `Mooziac_DownloadProgress` | DownloadManager | download UI | progress |
| `Mooziac_DownloadQueueChanged` | DownloadManager | download UI | queue change |
| `Mooziac_historyUpdated` | HistoryManager | history views | history change |
| `Mooziac_LikedSongsUpdated` | LikedSongsManager | liked songs views | like change |
| `Mooziac_SignInStatusChanged` | YTMWebView / NowPlayingManager | MainViewController | sign-in |
| `NetworkMonitorStatusChanged` | NetworkMonitor | NowPlayingManager, DownloadManager, HistoryManager | network |
| `NetworkMonitorReconnected` | NetworkMonitor | DownloadManager | reconnected |
| `YTM_playerDesignChanged` | MainViewController | player views | design change |
| `ProgressStyleDidChange` | ProgressStyleManager | progress views | progress style |
| `YTM_reloadWebView` | MainViewController | YTMWebView | reload |
| `YTM_ambientThemeChanged` | ambient theme | views | theme |
| `com.apple.screenIsLocked` | system | NowPlayingManager, AudioRouteMonitor, EdgeVolumeEngine | lock |
| `com.apple.screenIsUnlocked` | system | same + resume | unlock |
| App lifecycle | system | various | launch/terminate/active |

## 2. KVO / object observation

| Observer | Target | Key path | Purpose |
| :--- | :--- | :--- | :--- |
| `NativeAudioPlayer` | AVPlayerItem | `status`, `AVPlayerItemDidPlayToEndTime` | playback end |
| `AudioRouteMonitor` | CoreAudio default device | property listener | output change |
| `EdgeVolumeEngine` | Multitouch edge | private API events | right-edge swipe |
| `YTMWebView` | WKWebView | content process / lifecycle | crash recovery |

## 3. Closure observers

- `NowPlayingManager.registerObserver(observer:)` — the main fan-out (MainViewController → player pill, DiscordRPC, lyrics HUD, TrackNotificationManager).
- `PlaybackState` distribution through `notifyObservers()`.
- `StatusItemManager` panel state closures.

## 4. JS ↔ Swift bridge (WebKit)

- `WKScriptMessageHandler` in `ObserverBridge` → `nowPlayingHandler` messages → `PlaybackState`.
- JS `MutationObserver` in page → re-binds video events → messages.
- `URLFilter.decidePolicyFor` → content-block allow/block decisions (not notification-based).

## Fan-out of `notifyObservers`

```
NowPlayingManager.currentState set
  → notifyObservers()
    ├─ MainViewController.updateObserverUI(nowPlaying:) → DynamicIslandPlayerView.updateState
    ├─ DiscordRPCManager.updatePresence(state)
    ├─ LyricsManager + HUD state reference
    ├─ TrackNotificationManager (track changed)
    └─ StatusItemManager (tooltip, icon)
```

## Related

- `03_ARCHITECTURE/EVENT_FLOW.md`, `10_BACKGROUND_SYSTEMS/EVENT_LISTENERS.md`.