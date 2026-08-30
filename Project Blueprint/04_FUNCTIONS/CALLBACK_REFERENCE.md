# Callback Reference

Every important callback / closure / observer / selector / handler in Mooziac, with where it is registered and where its behavior is documented. Deep per-callback detail is in the raw discovery notes.

## 1. NotificationCenter block observers

| Observer registered in | Name | Handles | Documented |
| :--- | :--- | :--- | :--- |
| `NowPlayingManager.setupSleepObservers` | `com.apple.screenIsLocked` / `screenIsUnlocked` | `isSystemSleeping` flag → auto-pause/resume | 01 |
| `NowPlayingManager.setupNetworkObserver` | `NetworkMonitorStatusChanged` | engine mode fallback | 01 |
| `YTMWebView` (init) | `YTM_reloadWebView` | reload + restore web session | 02 |
| `DynamicIslandPlayerView.setupUI` (5 observers) | `YTM_playerDesignChanged`, `Mooziac_LibraryUpdated`, download progress/queue | theme, download button | 05 |
| `PlaylistLibraryView.setupObservers` | `YTM_playerDesignChanged`, `YTM_ambientThemeChanged`, `Mooziac_LibraryUpdated`, `NetworkMonitorStatusChanged` | theme + library refresh | 06 |
| `OfflineLibraryView.setupObservers` | `YTM_playerDesignChanged`, `YTM_ambientThemeChanged` | theme | 06 |
| `WaveformProgressView` | `ProgressStyleDidChange` | re-render progress style | 06 |
| `PlaylistManager` (init) | `Mooziac_LibraryUpdated` | refresh playlists | 03 |
| `DisplayManager.setupObservers` | `didChangeScreenParametersNotification` | geometry recompute | 01 |
| `StatusItemManager.setupPanel` | `NSWindow.didMoveNotification` | panel drag handling | 01 |
| `AudioRouteMonitor` (selectors) | `com.apple.screenIsLocked/Unlocked` | pause/resume | 02 |
| `EdgeVolumeEngine` (blocks) | `com.apple.screenIsLocked/Unlocked` | disable/re-enable engine | 02 |

> ⚠ Observer-removal gaps: `PlaylistLibraryView`, `OfflineLibraryView`, `HeaderView`, and `DynamicIslandPlayerView` register block observers with **no `deinit` removal** (see `15_ISSUES_AND_RISKS`).

## 2. WKScriptMessageHandler

| Handler | Registered by | Documented |
| :--- | :--- | :--- |
| `"nowPlayingHandler"` | `ObserverBridge.setupInWebView` (`removeScriptMessageHandler` + `add(self, name:)`) | 01 |

## 3. Target/action selectors

- **Status item**: `statusItemClicked(_:)`.
- **Context menu**: `didSelectGestureMapping(_:)`, `showGestureTutorialFromMenu`, `selectDownloadLocationFromMenu`, `resetDownloadLocationFromMenu`, `clearListeningHistoryFromMenu`, `resetLoginFromMenu`, `reloadFromMenu`, `quitFromMenu`. *(7 declared-but-unwired toggles: `toggleFromMenu`, `toggleCenteredLyricsFromMenu`, `toggleMasterGestures`, `toggleAutoPauseOnDisconnect`, `toggleRightEdgeVolume`, `toggleRightCornerTaps`, `toggleLeftCornerTaps`.)*
- **Player drawer**: ~40 `@objc` selectors in `SettingsPanel.swift` (play/play-next/add-to-queue/add-to-playlist/like/download/show-in-finder/remove/delete/move-up/move-down/etc. for playlists, liked songs, downloads, history).
- **Library views**: ~40 context-menu selectors + table drag-drop + double-click/return handlers in `PlaylistLibraryView` and `OfflineLibraryView`.
- **Header**: `headerViewDidTap*` (delegate, not selector).

## 4. Delegate callbacks

| Protocol | → | Methods | Documented |
| :--- | :--- | :--- | :--- |
| `DynamicIslandPlayerViewDelegate` | `MainViewController` | 13 callbacks (search, play/pause, next, prev, shuffle*, repeat*, seek, browser, offline lib, playlist lib, reset position, expanded) | 01/05 |
| `OfflineLibraryViewDelegate` | `MainViewController` | select track, close, import | 01/06 |
| `PlaylistLibraryViewDelegate` | `MainViewController` | close, play online | 01/06 |
| `HeaderViewDelegate` | `MainViewController` | back/forward/reload/home/account/playerOnly/quit | 01/06 |
| `NSSearchFieldDelegate` / `NSControlTextEditingDelegate` | player + library views | search text changes, return keys | 05/06 |
| `NSTableViewDelegate`/`DataSource` | library views | viewFor, heightOfRow, drag/drop, menu | 06 |
| `NSApplicationDelegate` | `AppDelegate` | launch/terminate | 01 |
| `UNUserNotificationCenterDelegate` | `TrackNotificationManager` | notification presentation | 04 |

## 5. Closures (state/ownership-relevant)

| Closure | Registered by | Notes | Documented |
| :--- | :--- | :--- | :--- |
| Observer callbacks (`NowPlayingManager.addObserver`) | `MainViewController`, `CenteredMenuBarLyricsWindowController`, player views | receive `PlaybackState` on every tick | 01 |
| `MainViewController.onChangeSize` / `onResetPosition` | `StatusItemManager` | window sizing/reset | 01 |
| `DisplayManager.onDisplayConfigurationChanged` | `StatusItemManager` | reposition | 01 |
| `NativeCapsuleToggleView.onToggle` | ContextMenu capsule items | setting toggles | 01 |
| `DownloadManager` task completions | views | download finished/cancelled | 03 |
| `KeyboardCommandHandler.handle(keyCode:isRepeat:showOverlay:)` | StatusItemManager key monitor | key commands | 01/02 |
| `EdgeVolumeEngine` haptic/overlay callbacks | self | volume overlay | 02 |
| `AppArtworkHelper` completion handlers | artwork consumers | async image load | 04 |
| `LyricsManager.fetchLyrics` completion | lyrics consumers | async lyrics | 04 |

## 6. System / C callbacks

| Callback | Registered by | Documented |
| :--- | :--- | :--- |
| Multitouch contact-frame C callback (`MTContactFrameCallback` bit-cast, `MTRegisterContactFrameCallback`/`MTRegisterContactObserver`) | `EdgeVolumeEngine` | 02 |
| CoreAudio property listener (`AudioObjectAddPropertyListener` on `kAudioObjectProperty_DefaultOutputDevice`) | `AudioRouteMonitor` | 02 |
| `NWPathMonitor.pathUpdateHandler` | `NetworkMonitor` | 04 |
| Pipe `readabilityHandler` (download progress stdout) | `DownloadManager` | 03 |
| `Process` termination handler | `DownloadManager` | 03 |
| `AVPlayerItem` periodic time observer (0.25 s) | `NativeAudioPlayer` | 02 |

## 7. Injected JS functions (bridge callbacks)

`updateNowPlaying`, `bindVideoEvents` (`play`/`pause`/`ended`), `findAndPlayTopTrack`, `simulateClick`, queue fns, EQ fns — see `01_CORE_LAYER.md` and `02_AUDIO_WEB_INPUT.md`.