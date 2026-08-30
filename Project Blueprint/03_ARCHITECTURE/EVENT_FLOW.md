# Event Flow

Every important event system in Mooziac, with emitters, payloads, listeners, and effects. Names are exact strings verified from source.

## NotificationCenter notifications (default center)

| Name | Posted (file:line) | Observed by | Payload | Effect |
| :--- | :--- | :--- | :--- | :--- |
| `"Mooziac_LibraryUpdated"` | `LocalLibraryManager.swift:150` (scan completion, `foundTracks`) | `PlaylistManager:87`, `DynamicIslandPlayerView/Core:229`, `PlaylistLibraryView:365` | `[LocalTrack]` | Refresh libraries/playlists/player download button |
| `"Mooziac_DownloadProgress"` | `DownloadManager.swift:27` (`progressNotification`) | `DynamicIslandPlayerView` (tooltip), `DetailItemRowView`, `HistoryRowView` | `DownloadProgressInfo` | Update download status UI |
| `"Mooziac_DownloadQueueChanged"` | `DownloadManager.swift:28` (`queueNotification`) | drawer/download views | queue snapshot | Refresh download rows |
| `"Mooziac_EngineModeChanged"` | `NowPlayingManager:34,41`, `ObserverBridge:351` | **NO listeners in repo** (inert) | none | — |
| `"YTM_playerDesignChanged"` | `PlayerDesign.swift:21` | `Core.swift:177,186`, `PlaylistLibraryView:362`, `OfflineLibraryView:252` | none | Re-apply theme across UI |
| `"YTM_ambientThemeChanged"` | `ArtworkTheme.swift:115` | `PlaylistLibraryView:363`, `OfflineLibraryView:253` | none | Re-apply ambient colors |
| `"ProgressStyleDidChange"` | `ProgressStyle.swift:29` | `WaveformProgressView:73` | none | Re-render progress style |
| `"Mooziac_historyUpdated"` | `HistoryManager.swift:7` | history UI rows | none | Refresh history list |
| `"Mooziac_LikedSongsUpdated"` | `LikedSongsManager.swift:7` | liked-songs UI rows | none | Refresh liked songs |
| `"Mooziac_SignInStatusChanged"` | `LikedSongsManager.swift:8` | sign-in-sensitive UI | none | Update sign-in UI |
| `"NetworkMonitorStatusChanged"` | `NetworkMonitor.swift:8` | `NowPlayingManager.setupNetworkObserver`, `PlaylistLibraryView`, `YTMWebView` | reachability | Toggle online/offline behavior, overlays |
| `"NetworkMonitorReconnected"` | `NetworkMonitor.swift:9` | listeners | none | Reconnect handlers |
| `"YTM_reloadWebView"` | (context menu "Restart Web Engine") | `YTMWebView.swift:103` | none | Reload webview + restore |

## AppKit / NSWorkspace / distributed notifications

| Name | Kind | Observed by | Effect |
| :--- | :--- | :--- | :--- |
| `NSApplication.didChangeScreenParametersNotification` | NotificationCenter | `DisplayManager.setupObservers` | Recompute geometry, reposition windows |
| `NSWindow.didMoveNotification` | NotificationCenter | `StatusItemManager.setupPanel` | Detect panel drag → dock/float logic |
| `NSApplication.didResignActiveNotification` | NotificationCenter | `StatusItemManager.startEventMonitors` | Close panel behavior |
| `NSWorkspace.willSleepNotification` | NSWorkspace center | `NowPlayingManager.setupSleepObservers` | `isSystemSleeping = true` → auto-pause |
| `NSWorkspace.didWakeNotification` | NSWorkspace center | `NowPlayingManager.setupSleepObservers` | `isSystemSleeping = false` → optional resume |
| `"com.apple.screenIsLocked"` | Distributed | `NowPlayingManager`, `AudioRouteMonitor:41`, `EdgeVolumeEngine:256` | Pause playback; disable edge engine; `isSleeping=true` |
| `"com.apple.screenIsUnlocked"` | Distributed | same | Resume behavior; re-enable; `isSleeping=false` |
| `NSApplication.didBecomeActive` (implicit) | — | various | — |
| `AVPlayerItemDidPlayToEndTime` | NotificationCenter | `NativeAudioPlayer.setupEndObserver` | Repeat-one / next / playlist advance |

## JS bridge events

- **`nowPlayingHandler`** (WKScriptMessage, registered in `ObserverBridge.setupInWebView`): 15-field dict — `title, artist, album, artworkUrl, isPlaying, currentTime, duration, playbackRate, pageUrl, videoId, trackID, isLiked, isShuffle, isRepeat` plus special events `{event:"videoEnded", videoId}`.
- **JS globals set by app**: `window.ytmObserverInjected` (injection guard), `window.ytmRepeatMode` (0/1), `window.ytmShuffleActive`, `window.clickYTMElement` (click helper), `window.ytmAudioContext`/`ytmSource`/`ytmLowFilter`/`ytmMidFilter`/`ytmHighFilter` (EQ graph), `video.ytmBound` (event-binding guard).

## Delegate callbacks

| Protocol | → | Callbacks |
| :--- | :--- | :--- |
| `DynamicIslandPlayerViewDelegate` | `MainViewController` | `dynamicIslandDidSearch`, `DidTapPlayPause`, `DidTapNext`, `DidTapPrevious`, `DidTapShuffle` (unused), `DidTapRepeat` (unused), `DidSeek(to:)`, `DidTapWebBrowser`, `DidTapResetPosition`, `DidTapOfflineLibrary`, `DidTapPlaylistLibrary(playlistID:)`, `DidToggleExpanded` |
| `OfflineLibraryViewDelegate` | `MainViewController` | `offlineLibraryDidSelectTrack(_:in:)`, `DidRequestClose`, `DidRequestImport` |
| `PlaylistLibraryViewDelegate` | `MainViewController` | `playlistLibraryDidRequestClose`, `playlistLibraryDidPlayOnline(videoId:)` |
| `HeaderViewDelegate` | `MainViewController` | `headerViewDidTapBack/Forward/Reload/Home/Account/PlayerOnly/Quit` |
| Closures | `StatusItemManager` | `MainViewController.onChangeSize`, `onResetPosition`; `DisplayManager.onDisplayConfigurationChanged` |
| `NativeCapsuleToggleView.onToggle` | context menu | setting toggles |
| `KeyboardCommandHandler.handle(keyCode:isRepeat:showOverlay:)` | StatusItemManager key monitor | key commands |

## Media / system events

- `MPNowPlayingInfoCenter`: written by `NowPlayingManager.updateSystemNowPlayingInfo` (title/artist/album/elapsed/duration/rate). **No `MPMediaItemArtwork`; no `MPRemoteCommandCenter` handlers registered in the codebase** (media-key handling may be absent — see `15_ISSUES_AND_RISKS`).
- `AudioRouteMonitor`: CoreAudio listener (`AudioObjectAddPropertyListener` on `kAudioObjectProperty_DefaultOutputDevice`) → pause on device change (when `isSleeping==false` and preference enabled).
- `NetworkMonitor`: `NWPathMonitor` pathUpdateHandler → posts status/reconnected notifications.

## Selector actions (target/action)

- Status button: `statusItemClicked(_:)`.
- Context menu: `didSelectGestureMapping(_:)`, `showGestureTutorialFromMenu`, `selectDownloadLocationFromMenu`, `resetDownloadLocationFromMenu`, `clearListeningHistoryFromMenu`, `resetLoginFromMenu`, `reloadFromMenu`, `quitFromMenu`.
- **Declared but never wired**: `toggleFromMenu`, `toggleCenteredLyricsFromMenu`, `toggleMasterGestures`, `toggleAutoPauseOnDisconnect`, `toggleRightEdgeVolume`, `toggleRightCornerTaps`, `toggleLeftCornerTaps` (replaced by capsule toggles).
- Player & library views: ~40 `@objc` context-menu selectors (see `04_FUNCTIONS/CALLBACK_REFERENCE.md` and raw notes 05/06).