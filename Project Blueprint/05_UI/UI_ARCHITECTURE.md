# UI Architecture

Mooziac's entire UI is code-built AppKit (no nibs/storyboards; one SwiftUI launch overlay). It is a **menu-bar-first** app: a status item shell hosts an `NSPanel` that contains the Dynamic Island player, which itself can expand a settings drawer and open full library/web views.

## View hierarchy

```
NSStatusItem (menu bar)
 └─ NSStatusItem.button (icon; click/scroll/right-click)
     └─ ContextMenu (NSMenu, right-click)
 └─ StatusItemPanel (NSPanel, transparent glass)
     └─ MainViewController (NSViewController)
         ├─ DynamicIslandPlayerView (compact pill / expanded drawer)
         │    ├─ PillContainerView (content + background)
         │    │    ├─ title/artist labels, artworkImageView
         │    │    ├─ controls row (playPause, next, previous, like, repeat)
         │    │    ├─ waveformProgressView (seek bar)
         │    │    ├─ search field + search icon
         │    │    ├─ toastView
         │    │    └─ settings drawer (SettingsPanel content):
         │    │         ├─ playlists section (nav, rows, detail)
         │    │         ├─ downloads / history / liked sections
         │    │         └─ features row (themes, toggles)
         ├─ browserContainerView (PassthroughBrowserContainerView)
         │    ├─ HeaderView (toolbar: back/forward/reload/home/account/mode/quit)
         │    └─ YTMWebViewContainer (WKWebView)
         ├─ OfflineLibraryView (local track browser)
         ├─ PlaylistLibraryView (playlists/liked/downloads/history tables)
         └─ OfflineOverlayView (network banner)

Separate windows:
 ├─ CenteredMenuBarLyricsWindowController (HUD, always-visible overlay window)
 ├─ LaunchAnimationController + LaunchOverlayView (startup animation)
 └─ NativeGestureTutorialWindowController (gesture tutorial, WKWebView of trackpad.html)
```

## UI subsystems

| Subsystem | Files | Role |
| :--- | :--- | :--- |
| Player | `Views/Player/DynamicIslandPlayerView/Core.swift` + `SettingsPanel.swift` + `ArtworkTheme.swift` | The pill player + drawer |
| Libraries | `Views/Libraries/*` | Offline browser, playlist/liked/downloads/history tables, swipe-delete, offline banner |
| Components | `Views/Components/*` | Reusable controls (search, toggle, slider, button, waveform, download ring) |
| Windows | `Views/Windows/*` | HUD, launch, tutorial |
| Menu bar | `Core/StatusItemManager/*` | Icon, panel, context menu |

## Design system (from README + source)

- **8px spacing grid**, 3-row compact layout that never overlaps regardless of title length.
- Glassmorphic / liquid-glass panels; `NSVisualEffectView` frosted backdrops in panels and library views.
- 3 themes via `PlayerDesign`: `.adaptive` (ambient artwork colors), `.darkMode` (OLED pitch black), `.glassMode` (premium warm off-white #F1F0EC). *(`.native` maps to `.adaptive` — unreachable in practice.)*
- Spring animations: `animatePop`, `animateSpinPop`, `animateBounce`, heart-pop.
- Reactive icon buttons with hover glow and bounce.
- Waveform seek bar with live scrub tooltip and `mm:ss` times.

## Key UI-state wiring

- UI never holds the source of truth — it mirrors `NowPlayingManager.shared.currentState` (`PlaybackState`) pushed via observers, and re-renders on notifications (`YTM_playerDesignChanged`, `ProgressStyleDidChange`, `Mooziac_LibraryUpdated`, `Mooziac_DownloadProgress`, `NetworkMonitorStatusChanged`).
- Views communicate outward via **delegates** (`DynamicIslandPlayerViewDelegate`, `OfflineLibraryViewDelegate`, `PlaylistLibraryViewDelegate`, `HeaderViewDelegate`) handled by `MainViewController`.
- Detail: `05_UI/UI_STATE_FLOW.md` and raw notes 05/06.