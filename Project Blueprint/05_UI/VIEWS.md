# Views

Catalog of all custom views, organized by area. Deep per-view detail (properties, methods, drawing, events) is in raw notes 05 and 06.

## Player

### DynamicIslandPlayerView (Core.swift, 1,176 lines)
The central pill player. Responsibilities:
- 3-row 8px-grid compact layout: (1) title/artist + like/theme/(ellipsis), (2) transport controls + search, (3) waveform + time.
- Transport: play/pause, next, previous, like (heart + pop), repeat (repeat/repeat.1 + cyan), shuffle (unused selector), download ring button, browser button, add-to-playlist button, reset-position button.
- Search: `GlassSearchField` that slides out (0.30 s) on search-icon tap; submits via `dynamicIslandDidSearch`.
- Waveform: `InteractiveWaveformProgressView` with click/drag seek (`dynamicIslandDidSeek`).
- Drawer: double-click or pill-background-click expands `SettingsPanel` content (`collapseSettings`/`expandPreferences`/`expandAddToPlaylist`/`expandSettingsPanel`).
- Feedback: `showToastBanner(message:isWarning:)` (2.8 s), keyboard handling (`keyDown` → `KeyboardCommandHandler`).
- Theme: applies `PlayerDesign` + ambient colors; registers 5 NotificationCenter observers (never removed).

### ArtworkTheme (ArtworkTheme.swift, 227 lines)
- `loadArtwork(urlStr:)` — URLSession fetch → ImageIO thumbnail (≤128 px) → fade-in `artworkImageView`.
- `ambientDominantColor(from cgImage:)` — raw bitmap sampling → average dominant color.
- `updateAmbientGlow(cgImage:)` — tints pill background + border from artwork; posts `YTM_ambientThemeChanged`.

### SettingsPanel (SettingsPanel.swift, 3,546 lines)
Extension of `DynamicIslandPlayerView`. Hosts the expandable drawer:
- Playlists section (nav tabs: Playlists / Liked / Downloads / History; create/search/selection/detail).
- Feature rows (theme, progress style, app-only sound, master gestures, lyrics, Discord).
- Row helpers: `DownloadRowView`, `DetailItemRowView`, `HistoryRowView`, `LikedSongRowView`, `LibraryNavButton`, flipped scroll/doc views, `VerticalPanGestureRecognizer`.
- Right-click context menus for each row type (see `05_UI/MENUS.md`).

## Libraries

| View | File | Role |
| :--- | :--- | :--- |
| `PlaylistLibraryView` | 3,408 lines | 5-mode library (Playlists, Liked Songs, Downloads, History via `Tab`/`Mode`); `PlaylistTableView` + 5 cell classes; drag-reorder; ~55 context-menu items; search filtering; bulk select/delete |
| `OfflineLibraryView` | 941 lines | Local track browser: search, sort, play, import; `OfflineTableView` + `OfflineTrackCellView`; status bar for download warnings |
| `OfflineOverlayView` | 117 lines | "Working offline" banner with retry |
| `SwipeToDeleteContainerView` | 644 lines | Swipe-to-delete row container (`SwipeActionCoordinator`, `SwipeContentCardView`) |

## Components

| Component | File | Behavior |
| :--- | :--- | :--- |
| `GlassSearchField` (+ `GlassSearchFieldCell`) | 237 | Vertically-centered glass search field; soft-gray focus border; clear button |
| `InteractiveWaveformProgressView` | 324 | Waveform bars, click/drag seeking, scrub tooltip, elapsed/remaining |
| `ReactiveIconButton` | 250 | SF Symbol button; hover glow; `animatePop`/`animateBounce`/`animateHeartPop`/`animateSpinPop` |
| `CircularProgressDownloadButton` | 198 | Radial download progress ring (idle/queued/downloading/done/cancelled) |
| `NativeCapsuleToggleView` | 69 | Capsule switch |
| `LiquidSegmentedControl` + `SettingsTone` | 310 | Liquid segmented control for tone/tab switching; `PassThroughView` |
| `HeaderView` | 122 | Browser-mode toolbar (back/forward/reload/home/account/player-only/quit) |

## Windows

See `05_UI/WINDOWS.md` (lyrics HUD, launch, tutorial).

## Menu bar

`StatusItemManager` — status icon (`MenuBarIcon.png`/`@2x`), left-click toggles panel, scroll adjusts volume (±4%/scroll), right-click context menu; drag-out to float; keyboard monitor.