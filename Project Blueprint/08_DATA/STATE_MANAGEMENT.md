# State Management

How application state is stored and propagated.

## Core state owner: `NowPlayingManager`

- Single canonical snapshot: `PlaybackState` (`currentState`).
- `notifyObservers()` → registered observers (MainViewController-driven view updates, DiscordRPC, lyrics HUD, TrackNotificationManager).
- Network & engine state: `isNetworkAvailable`, `engineMode`.
- Sign-in: `isSignedIn` (cookie-based detection via `YTMWebView`), `YTM_hasLoggedInOnce`.

## Observer pattern

| Observer target | Registered by | Notified on |
| :--- | :--- | :--- |
| MainViewController observers | `registerObserver(observer:)` | any `notifyObservers()` |
| Discord presence | `DiscordRPCManager` | key changes (title/artist/artwork/pageUrl) |
| Lyrics HUD | `CenteredMenuBarLyricsWindowController` | state changes + own 0.1 s timer |
| Track notifications | `TrackNotificationManager` | track changes |
| Library views | `LocalLibraryManager` | `Mooziac_LibraryUpdated` |

## Settings state (UserDefaults — 38 keys)

| Group | Keys |
| :--- | :--- |
| Player design | `YTM_playerDesign`, `YTM_ambientThemeChanged`, `YTM_playerDesignChanged`, `YTM_progressStyle`, `YTM_v3_useWaveformProgress` |
| Gesture engines | `YTM_isEdgeEngineEnabled`, `YTM_v3_isEdgeEngineEnabled`, `YTM_isRightEdgeVolumeEnabled`, `YTM_v3_isRightEdgeVolumeEnabled`, `YTM_isRightCornerTapsEnabled`, `YTM_v3_isRightCornerTapsEnabled`, `YTM_isLeftCornerTapsEnabled`, `YTM_v3_isLeftCornerTapsEnabled` |
| Lyrics | `YTM_isCenteredLyricsEnabled`, `YTM_v3_isCenteredLyricsEnabled` |
| Volume | `YTM_preMuteVolume`, `YTM_lastKnownSystemVolume`, `Mooziac_MediaVolume` |
| Auto-pause | `YTM_isAutoPauseOnDisconnectEnabled` |
| Discord | `YTM_discordRPC_enabled` |
| Downloads | `YTM_downloadsFolder` |
| Window | `YTM_playerFrameX`, `YTM_playerFrameY`, `YTM_playerTopY`, `YTM_savedDisplayID`, `YTM_isDraggedFromDock` |
| Session | `YTM_lastVideoId`, `YTM_lastTitle`, `YTM_lastArtist`, `YTM_lastArtwork`, `YTM_lastUrl`, `YTM_lastTime`, `YTM_lastDuration`, `YTM_lastIsLiked`, `YTM_likedTrackKeysSet` |
| Init | `YTM_hasLoggedInOnce`, `YTM_hasInitializedDefaultSettingsV2`, `YTM_reloadWebView` |
| Offline playback | `Mooziac_LastPlayedLocalTrackId`, `Mooziac_LastPlayedLocalTrackTitle` |

⚠ `NowPlayingManager.init` **deletes** `YTM_likedTrackKeysSet` and `YTM_lastIsLiked` on every launch (risk A3 — like state reset).

## Notification state (18 names)

| Notification | Poster(s) | Purpose |
| :--- | :--- | :--- |
| `Mooziac_EngineModeChanged` | NowPlayingManager (3×) | engine switch — **no listeners** |
| `Mooziac_LibraryUpdated` | LocalLibraryManager | library refresh |
| `Mooziac_DownloadProgress` | DownloadManager | download progress |
| `Mooziac_DownloadQueueChanged` | DownloadManager | queue change |
| `Mooziac_historyUpdated` | HistoryManager | history change |
| `Mooziac_LikedSongsUpdated` | LikedSongsManager | liked songs change |
| `Mooziac_SignInStatusChanged` | YTMWebView/NowPlayingManager | sign-in change |
| `NetworkMonitorStatusChanged` | NetworkMonitor | network status |
| `NetworkMonitorReconnected` | NetworkMonitor | reconnected |
| `YTM_playerDesignChanged` | MainViewController | design change |
| `ProgressStyleDidChange` | ProgressStyleManager | progress style |
| `YTM_reloadWebView` | MainViewController | webview reload |
| `YTM_ambientThemeChanged` | (ambient) | theme |
| `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` | system | lock/unlock |
| `NSApplication.didFinishLaunching` etc. | system | app lifecycle |

## Data flow conventions

```
Event (UI/JS/system) → Manager mutates state → notifyObservers / NotificationCenter
                     → UI observers refresh → (optional) persist to UserDefaults/SQLite
```

- Library data flows: SQLite → `LocalLibraryManager.allTracks` → views; writes funnel through managers.
- Downloads: `DownloadManager` posts notifications; views re-read state.
- Window state: persisted to `YTM_playerFrame*`; restored at launch.

## Related

- `08_DATA/STORAGE.md`, `03_ARCHITECTURE/EVENT_FLOW.md`, `00_INDEX/MASTER_INDEX.md`.