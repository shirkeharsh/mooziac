# Settings

Every user-facing setting, its storage key, and its effect. Keys are exact strings from source.

## 1. In the player drawer (SettingsPanel feature rows)

| Setting | UI | Storage / backing | Effect |
| :--- | :--- | :--- | :--- |
| Theme | `makeThemeFeatureRow` → cycle tap | `PlayerDesign.current` → `UserDefaults "YTM_playerDesign"`; posts `YTM_playerDesignChanged` | Re-theme entire UI (adaptive/dark/glass) |
| Progress style | `makeProgressStyleFeatureRow` → cycle tap | `ProgressStyle.current` → `"YTM_progressStyle"` (+ legacy `YTM_v3_useWaveformProgress`); posts `ProgressStyleDidChange` | Waveform vs liquid capsule vs minimal line |
| App-Only Sound | `NativeCapsuleToggleView` | `AppVolumeManager.isAppVolumeOnly` → `"YTM_isAppVolumeOnly"` (implied; stored in manager) | Volume gestures affect only app/web, not system |
| Master Gestures | capsule | `EdgeVolumeEngine.isEnabled` | Enables/disables trackpad gestures |
| Lyrics HUD | capsule | `CenteredMenuBarLyricsWindowController.isEnabled` → `"YTM_v3_isCenteredLyricsEnabled"` | Shows/hides menu-bar lyrics overlay |
| Discord Presence | capsule | `DiscordRPCManager.isEnabled` → `"YTM_discordRPC_enabled"` (default true) | Rich presence on/off |

## 2. Status item context menu settings

| Setting | Action |
| :--- | :--- |
| Gesture toggles (master, auto-pause on disconnect, right-edge volume, right-corner taps, left-corner taps) | capsule items in ContextMenu (some wired to `EdgeVolumeEngine`/`AudioRouteMonitor`; matching `toggle*` selectors are dead) |
| Downloads folder | `selectDownloadLocationFromMenu` / `resetDownloadLocationFromMenu` → `"YTM_downloadsFolder"` |
| Clear listening history | `clearListeningHistoryFromMenu` |
| Reset login | `resetLoginFromMenu` → `flushSessionState(keepCookies:false)` |
| Restart web engine | `reloadFromMenu` → `"YTM_reloadWebView"` |

## 3. Playback/auto behaviors (from preferences)

| Behavior | Backing | Source |
| :--- | :--- | :--- |
| Auto-pause on screen lock/sleep | DNC `com.apple.screenIsLocked` + willSleep | `NowPlayingManager.setupSleepObservers`, `AudioRouteMonitor`, `EdgeVolumeEngine` |
| Auto-pause on device disconnect | `"YTM_isAutoPauseOnDisconnectEnabled"` | `AudioRouteMonitor` |
| Auto-resume on unlock | preference-gated resume in `NowPlayingManager` | — |
| Session restore on launch | `"YTM_lastUrl"`, `"YTM_lastTime"`, `"YTM_lastVideoId"` | `YTMWebView.restoreAndPlayJS` |

## 4. Download manager settings

- Downloads folder default `~/Music/Mooziac` (see above); downloads saved under it.
- Dedup, format conversion, and player-client selection are internal to `DownloadManager` (no user-visible settings).

## 5. Legacy keys purged at launch (`AppDelegate`)

`YTM_isEdgeEngineEnabled`, `YTM_isCenteredLyricsEnabled`, `YTM_isRightEdgeVolumeEnabled`, `YTM_isRightCornerTapsEnabled`, `YTM_isLeftCornerTapsEnabled`, `YTM_hasInitializedDefaultSettingsV2`, `YTM_isDraggedFromDock`, `YTM_playerFrameX`, `YTM_playerFrameY`, `YTM_playerTopY` — **removed every launch** so clean v3 keys default OFF.

## 6. Legacy keys deleted on init (`NowPlayingManager.init`)

`YTM_likedTrackKeysSet`, `YTM_lastIsLiked` — deleted every launch (liked state reset to JS truth each start; see `15_ISSUES_AND_RISKS`).

## 7. Full UserDefaults key inventory

See `08_DATA/STATE_MANAGEMENT.md` (38 keys with read/write/remove sites).

## Where settings UI lives

- Player drawer feature rows: `SettingsPanel.swift` (`makeFeatureRow`, `makeThemeFeatureRow`, `makeProgressStyleFeatureRow`).
- Context menu toggles: `ContextMenu.swift` capsule items.
- Downloads folder: `ContextMenu.swift:179` + `LocalLibraryManager` (61/66).
- No separate Preferences window exists.