# Settings Workflow

How user settings are surfaced, changed, and persisted.

## Settings surface

- **Context menu** (`ContextMenu.swift`) on the status item is the primary settings UI:
  - Playback controls (play/pause, next, previous)
  - Like / dislike
  - Download current track
  - Player design (Adaptive / Dark / Glass / Native)
  - Progress style
  - Lyrics toggle (centered lyrics)
  - Discord RPC toggle
  - Engine toggles (edge volume, right/left corner taps)
  - Downloads folder setting
  - Sign-in / login reset (cookies)
  - History clear, liked songs
  - Quit
- **Preferences/plist**: none — all settings are UserDefaults keyed strings.

## Settings storage pattern

| Pattern | Example |
| :--- | :--- |
| Read | `UserDefaults.standard.bool(forKey: "YTM_isEdgeEngineEnabled")` |
| Write | `UserDefaults.standard.set(value, forKey: ...)` |
| Notify | post `YTM_playerDesignChanged`, `ProgressStyleDidChange`, `YTM_ambientThemeChanged`, etc. |

## Setting → effect wiring

| Setting (key) | Effect on change |
| :--- | :--- |
| `YTM_playerDesign` | re-skin player pill / panel; post `YTM_playerDesignChanged` |
| `YTM_progressStyle` | waveform ↔ capsule ↔ minimal; post `ProgressStyleDidChange` |
| `YTM_isCenteredLyricsEnabled` | show/hide lyrics HUD window |
| `YTM_discordRPC_enabled` | start/stop Discord presence |
| `YTM_isEdgeEngineEnabled` (+v3) | arm/disarm Multitouch engine |
| `YTM_isRightCornerTapsEnabled` / `YTM_isLeftCornerTapsEnabled` | tap gesture routes |
| `YTM_isAutoPauseOnDisconnectEnabled` | auto-pause on device disconnect |
| `YTM_downloadsFolder` | change offline music folder |
| `YTM_isRightEdgeVolumeEnabled` | edge volume mode |
| `YTM_v3_useWaveformProgress` | waveform usage |

## Init / seeding

- `initializeDefaultSettings` seeds defaults if `YTM_hasInitializedDefaultSettingsV2` is false.
- Startup removes **10 legacy keys** each launch (see `13_WORKFLOWS/APP_STARTUP.md`).

## Reset flows

| Action | What it clears |
| :--- | :--- |
| "Clear Web Cookies" (login reset) | `WKWebsiteDataStore` all data; `YTM_hasLoggedInOnce=false`; session keys (`flushSessionState(keepCookies:false)`); shows Google login |
| Clear history | `clearHistory()` → SQLite delete + `Mooziac_historyUpdated` |
| Reset player position | resets `YTM_playerFrame*` (double reset noted in risks) |

## Risks

- Some settings exist in legacy (`YTM_is*`) and current (`YTM_v3_*`) variants — inconsistent read paths.
- Toggling engine settings may not fully stop the private-framework engine (partial arm/disarm).
- No settings export/import.

## Related

- `08_DATA/STATE_MANAGEMENT.md`, `11_CONFIGURATION/CONFIG_FILES.md`.