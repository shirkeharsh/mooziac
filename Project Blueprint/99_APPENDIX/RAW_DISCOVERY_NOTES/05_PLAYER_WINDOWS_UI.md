# Mooziac — Technical Blueprint: Dynamic Island Player & Window Subsystems

Scope: 7 source files in `Sources/Mooziac/` covering the Dynamic Island player pill (views, settings drawer, artwork theming) and window-level UI (centered lyrics HUD, launch animation, gesture tutorial).

Legend: **[V]** = verified in source. **[I]** = INFERRED FROM SOURCE (reasonable inference, not runtime-verified). **[U]** = UNKNOWN — requires runtime verification.

---

# FILE 1 — `Views/Player/DynamicIslandPlayerView/Core.swift` (1176 lines)

## FILE ENTRY

- **File path**: `Sources/Mooziac/Views/Player/DynamicIslandPlayerView/Core.swift`
- **Purpose**: Core `NSView` implementation of the Dynamic Island style menu-bar player pill. Owns the whole compact player UI (artwork, track title, transport controls, search, waveform progress, toast banner) plus the collapsed/expanded settings drawer state machine and the delegate bridge to the app controller. Also defines the `PillContainerView` hit-testing container.
- **Subsystem**: Views → Player → DynamicIslandPlayerView (UI layer). Acts as the UI hub that routes user actions into `NowPlayingManager`, `DownloadManager`, `PlaylistManager`, `LikedSongsManager`, `HistoryManager`, `LocalLibraryManager`, `LyricsManager`, `KeyboardCommandHandler`, `NetworkMonitor`, `PlayerDesign`, `CenteredMenuBarLyricsWindowController`.
- **Dependencies (files it communicates with)**:
  - `Core/NowPlayingManager/NowPlayingManager.swift` — `shared.currentState`, `engineMode`, `setRepeatMode`, `toggleLike`.
  - `Managers/DownloadManager.swift` — `progressNotification`, `queueNotification`, `extractVideoID`, `shared.statusFor`, `cancelTask`, `queueTrack`.
  - `Managers/PlaylistManager.swift`, `Managers/LikedSongsManager.swift`, `Managers/HistoryManager.swift`, `Managers/LocalLibraryManager.swift` — playlist/liked/download/history data (mostly via SettingsPanel extension).
  - `Managers/LyricsManager.swift` — `cleanSongInfo`.
  - `Web/URLFilter.swift` — `containsLink`.
  - `Managers/NetworkMonitor.swift` — `statusChangedNotification`, `shared.isReachable`.
  - `Models/PlayerDesign.swift` — `PlayerDesign.current`.
  - `Input/KeyboardCommandHandler.swift` — `handle(keyCode:isRepeat:showOverlay:)`.
  - `Views/Windows/CenteredMenuBarLyricsWindowController.swift` — `shared.showCustomTextOverlay`.
  - `Managers/AppVolumeManager.swift`, `Managers/DiscordRPCManager.swift`, `Audio/EdgeVolumeEngine.swift`, `Managers/LocalDatabaseManager.swift` — via SettingsPanel.swift.
  - `Core/StatusItemManager/StatusItemManager.swift` — `positionCustomWindow` (used by tutorial window; indirect).
- **Imports**: `AppKit`, `QuartzCore`, `ImageIO`.
- **Classes defined**:
  - `protocol DynamicIslandPlayerViewDelegate`
  - `class DynamicIslandPlayerView: NSView, NSSearchFieldDelegate, NSControlTextEditingDelegate`
  - `final class PillContainerView: NSView`
- **Constants** (magic numbers, all **[V]**):
  - Pill: `cornerRadius = 20`, `borderWidth = 1.0`, border color `white 0.15 alpha`, background `NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.98)` (default collapsed pill).
  - Pill fixed width `360`.
  - Rows: artwork 44×44 at leading 16 / top 12; text stack 12pt gap, width ≤ 200; top-right stack trailing 16; controls 10pt below artwork; search height 24; waveform height 12; time label trailing 16; settings container height `295`.
  - Margins: leading/trailing 16 (outer), 12 (settings container inset), spacing 7 (controls stack), 6 (top-right stack), 8 (search spacing).
  - Fonts: title 13pt bold, artist 11pt medium, time 10pt monospaced digit regular, search 11pt medium.
  - Accent cyan used for active/highlight: `NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)`; repeat-active color `(0.0, 0.80, 1.0)`; like-heart red `(0.98, 0.25, 0.35)`.
  - Glass-mode dim tint `(0.082, 0.082, 0.082)`; idle tint `white 0.85`.
  - Animations: search expand 0.30s, collapse 0.28s; toast fade 0.25s, toast display 2.8s; settings reveal delay 0.15s; glow pulse 0.18s/0.12s.
  - Toast: cornerRadius 10, border `white 0.20`; warning border `(1.0, 0.40, 0.40, 0.70)`; success border `(0.30, 0.85, 0.40, 0.70)`; background `(0.12, 0.12, 0.15, 0.96)`.
- **Events observed** (NotificationCenter):
  - `"YTM_playerDesignChanged"` → `applyTheme`
  - `NetworkMonitor.statusChangedNotification` (`"NetworkMonitorStatusChanged"`) → `networkStatusChanged(_:)`
  - `"Mooziac_LibraryUpdated"` → `refreshPlaylistsSection()` + `updateDownloadButtonState()`
  - `HistoryManager.historyUpdatedNotification` → conditional refresh of history tab
  - `LikedSongsManager.likedSongsUpdatedNotification` → conditional refresh of liked tab
  - `DownloadManager.progressNotification` / `DownloadManager.queueNotification` → `updateDownloadButtonState()` + tooltip update on `playlistDetailDownloadAllButton`
- **Side effects**: Reads/writes UserDefaults (`YTM_lastTitle`, `YTM_lastArtist`, `YTM_lastArtwork`, `YTM_lastIsLiked`); posts no notifications itself; drives the delegate; calls into the playback managers directly for repeat/like.
- **Key observations**: `dynamicIslandDidTapShuffle()` and `dynamicIslandDidTapRepeat()` exist in the delegate protocol but are never invoked from this file **[I dead protocol members]**; `flashGlowOnButton()` has no caller in these two files **[I dead code]**; `isRepeatActive` and `themeSlider` are declared but never referenced here or in SettingsPanel.swift **[I dead code]**.

## CLASS ENTRY — `protocol DynamicIslandPlayerViewDelegate`

- **Purpose**: Outbound routing contract: the view forwards user intent to whoever owns it (the main controller).
- **Members** (`[V]`, all `func`):
  1. `dynamicIslandDidSearch(query: String)`
  2. `dynamicIslandDidTapPlayPause()`
  3. `dynamicIslandDidTapNext()`
  4. `dynamicIslandDidTapPrevious()`
  5. `dynamicIslandDidTapShuffle()` — **no call site in these files** `[I unused]`
  6. `dynamicIslandDidTapRepeat()` — **no call site; repeat handled internally** `[I unused]`
  7. `dynamicIslandDidSeek(to seconds: Double)`
  8. `dynamicIslandDidTapWebBrowser()`
  9. `dynamicIslandDidTapResetPosition()`
  10. `dynamicIslandDidTapOfflineLibrary()`
  11. `dynamicIslandDidTapPlaylistLibrary(playlistID: String?)`
  12. `dynamicIslandDidToggleExpanded(expanded: Bool)`
- **Consumers**: whoever sets `view.delegate` (the app-level controller — file not in this set; `[I]`).
- **What would break if removed**: all `delegate?.` call sites in Core.swift (search, transport, seek, browser, reset, offline library, expanded toggle) would become no-ops → the player would be visually dead.

## CLASS ENTRY — `DynamicIslandPlayerView`

- **Purpose**: The entire compact player UI + settings drawer + playlist library mini-viewer, presented inside a status-bar window (positioning is owned by `StatusItemManager`).
- **Responsibilities**:
  1. Render compact player state (title/artist/artwork, play/pause icon, repeat mode, like state, progress).
  2. Handle search expand/collapse + search submission.
  3. Handle the settings drawer (preferences vs playlist picker modes) with expand/collapse constraints.
  4. Show toast banners (network, download, playlist feedback).
  5. Route key events to `KeyboardCommandHandler`.
  6. Restore last-track state from UserDefaults on launch.
- **Init**: `override init(frame:)` and `required init?(coder:)` both call `setupUI()`, `restoreSavedState()`, register `applyTheme` + `networkStatusChanged(_:)` observers, then `applyTheme()`.
- **Properties** (all `[V]`, types):
  - `weak var delegate: DynamicIslandPlayerViewDelegate?`
  - `let containerPill = PillContainerView()`
  - `let artworkImageView = NSImageView()`
  - `let titleLabel = NSTextField(labelWithString: "Not Playing")`
  - `let artistLabel = NSTextField(labelWithString: "YouTube Music")`
  - `let addToPlaylistButton/previousButton/playPauseButton/nextButton/repeatButton/likeButton/searchIconButton = ReactiveIconButton()`
  - `let downloadButton = CircularProgressDownloadButton()`
  - `let browserButton/fullScreenButton/resetPositionButton = ReactiveIconButton()`
  - `var isLiked: Bool = false`
  - `var isRepeatActive: Bool = false` `[I dead]`
  - `var repeatMode: RepeatMode = .off`
  - `public enum ActiveSettingsMode { case preferences, playlist }`; `public var activeSettingsMode: ActiveSettingsMode = .preferences`
  - `public enum LibraryTab: Int, CaseIterable` — `playlists=0` ("Playlists", "music.note"), `likedSongs=1` ("Liked Songs", "heart"), `downloads=2` ("Downloads", "arrow.down.circle"), `history=3` ("History", "clock"); `public var activeLibraryTab: LibraryTab = .playlists`
  - `var containerPillBottomCollapsedConstraint / containerPillBottomSettingsConstraint: NSLayoutConstraint?`
  - `var isSettingsExpanded: Bool = false`
  - `let settingsContainerView = NSView()`
  - `let settingsHeaderLabel = NSTextField(labelWithString: "SETTINGS & OPTIONS")`
  - `let themeSlider = LiquidGlassSegmentedSlider()` `[I dead in these files]`
  - `let themeSectionLabel = NSTextField(labelWithString: "PLAYER THEME")` `[I dead — unused]`
  - `let playlistSectionLabel = NSTextField(labelWithString: "ADD CURRENT TRACK TO PLAYLIST")` (overwritten to "PLAYLISTS" in SettingsPanel)
  - `let libraryNavContainer = NSView()`, `let libraryNavStack = NSStackView()`, `var libraryNavButtons: [LibraryNavButton] = []`
  - `var isPlaylistCreateOpen: Bool = false`
  - `var playlistSearchWidthAnchor / playlistCreateWidthAnchor: NSLayoutConstraint?`
  - `let downloadsImportButton/downloadsPlayAllButton/downloadsShuffleButton = ReactiveIconButton()`
  - `let playlistsStackView = NSStackView()`, `let detailStackView = NSStackView()`
  - `let playlistDetailBackButton/playlistDetailPlayAllButton/playlistDetailShuffleButton/playlistDetailDownloadAllButton/playlistDetailCreateButton/playlistDetailDeleteButton/playlistDetailAddButton/playlistSearchToggleButton/playlistBulkDeleteButton/playlistSelectionDoneButton = ReactiveIconButton()`
  - `var isPlaylistSelectionMode: Bool = false`, `var selectedPlaylistIDs: Set<String> = []`
  - `var isPlaylistSearchActive: Bool = false`
  - `let inlineCreateContainer = NSView()`, `let inlineCreateTextField = NSTextField()`
  - `var playlistSearchField: GlassSearchField?`
  - `var playlistScrollView: NSScrollView?`
  - `var playlistActionRowStack / playlistHeaderStack: NSStackView?`
  - `var playlistDetailMode: PlaylistRecord?`
  - `var playlistAddMode: Bool = false`
  - `let featuresSectionLabel = NSTextField(labelWithString: "FEATURES")`
  - `let settingsDivider = NSView()`
  - `var featureIconViews: [NSImageView] = []`, `var featureTitleLabels: [NSTextField] = []`, `var featureDescLabels: [NSTextField] = []`
  - `var masterGesturesToggle/appVolumeToggle/lyricsToggle/discordToggle = NativeCapsuleToggleView()`
  - `var progressDescLabel / themeDescLabel: NSTextField?`
  - `public static var sharedAmbientBgColor: CGColor?`, `public static var sharedAmbientAccentColor: NSColor?` (artwork theming cache for other views)
  - `var lastAmbientBgColor/lastAmbientBorderColor: CGColor?`, `var lastAmbientAccentColor: NSColor?`
  - `var controlsStackCenterX/controlsStackLeading: NSLayoutConstraint?`
  - `let controlsStack = NSStackView()`
  - `let searchField = GlassSearchField()`
  - `let timeLabel = NSTextField(labelWithString: "0:00 / 0:00")`
  - `let waveformProgressView = InteractiveWaveformProgressView()`
  - `var lastArtworkUrl = ""`, `var lastTrackTitle = ""`, `var lastTrackArtist = ""`
  - `static let artworkCache = NSCache<NSString, NSImage>()`
  - `let toastView = NSView()`, `let toastLabel = NSTextField(labelWithString: "")`, `var toastDismissTimer: Timer?`
  - `private var lastPlayPauseIcon: String = ""`, `private var lastLikeState: Bool? = nil`
  - `var isCollapsingSearch = false`
  - `private var isPlaylistSubViewVisible: Bool` (computed; checks hidden state of `PlaylistSubView`-identified subview)
- **Public vs private API**: Delegate protocol is `public`-like (internal protocol); view class is `internal` (module-wide). Public-facing methods used by other files: `collapseSettings()`, `expandPreferences()`, `expandAddToPlaylist()`, `showToastBanner(message:isWarning:)`, `updateDownloadButtonState()`, `setResetPositionButtonHidden(_:)`, `updateState(_:)`. Everything else is internal/private.
- **Dependencies**: see FILE ENTRY.
- **Consumers**: `MainViewController`/app controller (delegate), `StatusItemManager` (hosts the window), `NowPlayingManager` (feeds `updateState`), settings panel code (SettingsPanel.swift).
- **Lifecycle**: created inside the status-bar window's content view (`[I]`); restores persisted last-track state in init; registers many NotificationCenter block observers in `setupUI()` that are **never removed** (no `deinit` in Core.swift) `[I potential leak / repeated-observer risk]`.
- **State**: `isSettingsExpanded`, `activeSettingsMode`, `activeLibraryTab`, `playlistDetailMode`, `playlistAddMode`, `isPlaylistSearchActive`, `isPlaylistCreateOpen`, `isPlaylistSelectionMode`, `selectedPlaylistIDs`, `isLiked`, `repeatMode`, `isCollapsingSearch`, `lastTrackTitle/Artist/Url`, ambient colors, download state (via `downloadButton`).
- **Events emitted**: `delegate?.` callbacks; `NotificationCenter.default.post` for `YTM_ambientThemeChanged` (in ArtworkTheme.swift).
- **Relationships**: 1 delegate; owns `PillContainerView` + settings subviews; delegate methods are the only outbound transport path.
- **What would break if removed**: the whole menu-bar player UI; `MainViewController`'s ability to show playback; the settings drawer; the launch animation's target position logic references the status item (independent).

## Layout (8px-ish grid, `setupUI`, lines 225–528)

Constrained inside `safeAreaLayoutGuide` of the hosting window content:

- **Pill** (`containerPill`): pinned top/leading/trailing to safe area, fixed width 360; height is driven by **bottom** anchor that switches between two constraints:
  - `containerPillBottomCollapsedConstraint` = pill bottom to `waveformProgressView.bottom + 12` (collapsed).
  - `containerPillBottomSettingsConstraint` = pill bottom to `settingsContainerView.bottom + 12` (expanded).
  - Only one is active at a time (`collapsedConstraint.isActive = true` default).
- **Toast banner** (`toastView`): centered horizontally, 6pt from pill top, height 24.
- **ROW 1** — artwork 44×44 at (16, 12); `topRightStack` (reset, download, fullscreen, browser) trailing 16, centerY aligned to `titleLabel`; `textStack` (title 13pt bold + artist 11pt, spacing 1, leading) from `artwork.trailing + 12`, top = `artwork.top + 2`, trailing to `topRightStack.leading − 8`, width ≤ 200.
- **ROW 2** — `controlsStack` (addToPlaylist, repeat, previous, playPause, next, like, search) centered via `controlsStackCenterX` (default active) OR leading-16 via `controlsStackLeading` (when search expands); top = `artwork.bottom + 10`. `searchField` leading = `controlsStack.trailing + 8`, trailing −16, height 24, centerY to controls.
- **ROW 3** — `waveformProgressView` leading 16, top = `controls.bottom + 12`, height 12, trailing to `timeLabel.leading − 10`; `timeLabel` trailing −16, centerY to waveform.
- **ROW 4** — `settingsContainerView` top = `waveform.bottom + 12`, inset 12, height fixed `295`.
- Committed constraints array lines 472–527. Grid evidence: 16pt outer margins, 12pt row gaps, 8pt item gaps → “8px grid” is really a 16/12/8 mixed spacing scheme `[I]`.

## Buttons & selectors table

| Button | SF Symbol | Tooltip | Selector | Line |
|---|---|---|---|---|
| addToPlaylistButton | `text.badge.plus` (13.5pt) | "Add to Playlist" | `#selector(addToPlaylistButtonTapped)` | 337 |
| repeatButton | `repeat` / `repeat.1` (14pt) | "Repeat Track / Playlist" | `#selector(repeatTapped)` | 338 |
| previousButton | `backward.fill` (14.3pt) | "Previous" | `#selector(previousTapped)` | 339 |
| playPauseButton | `play.fill`/`pause.fill` (16pt) | "Play/Pause" | `#selector(playPauseTapped)` | 340 |
| nextButton | `forward.fill` (14.3pt) | "Next" | `#selector(nextTapped)` | 341 |
| likeButton | `heart`/`heart.fill` (16pt) | "Like Track" | `#selector(likeTapped)` | 342 |
| searchIconButton | `magnifyingglass`/`xmark` (16pt) | "Search YouTube Music"/"Close Search" | `#selector(searchIconTapped)` | 343 |
| downloadButton | (progress ring) | "Download Song" | `#selector(downloadCurrentTrackTapped)` | 348 |
| fullScreenButton | `macwindow.on.rectangle` (13.5pt) | "Open Full Web Browser View" | `#selector(fullScreenTapped)` | 351 |
| browserButton | `ellipsis.circle.fill` (14.8pt) | "Player Settings & Options" | `#selector(browserTapped)` | 352 |
| resetPositionButton | `arrow.uturn.backward` (13.5pt) | "Snap Player Back to Menu Bar" | `#selector(resetPositionTapped)` | 353 (hidden initially) |

## FUNCTION ENTRIES — Core.swift

### `override init(frame:)` — line 173
- **Class**: DynamicIslandPlayerView. **Purpose**: designated init. **Inputs**: `frameRect: NSRect`.
- **Calls**: `setupUI()`, `restoreSavedState()`, NotificationCenter observers (`applyTheme`, `networkStatusChanged(_:)`), `applyTheme()`.
- **Side effects**: registers 2 selector-based observers; reads UserDefaults; applies theme.
- **Async**: none. **Errors**: none.

### `required init?(coder:)` — line 182
- Mirror of frame init for storyboard/NIB path. `[I]` unused (no NIB usage observed).

### `restoreSavedState()` — line 191
- **Purpose**: restore last track metadata on cold start.
- **Inputs**: none. **Reads**: UserDefaults keys `YTM_lastTitle`, `YTM_lastArtist`, `YTM_lastArtwork`, `YTM_lastIsLiked`.
- **Writes**: `titleLabel.stringValue`, `artistLabel.stringValue`, `lastArtworkUrl`, `isLiked`, `likeButton.image`, like color.
- **Calls**: `loadArtwork(urlStr:)`, `updateLikeButtonColor()`.
- **Side effects**: triggers artwork network fetch if `YTM_lastArtwork` present.

### `updateLikeButtonColor()` — line 213
- Sets `likeButton.contentTintColor` — red `(0.98,0.25,0.35)` when liked; glass `(0.082,0.082,0.082)` in glassMode else `white 0.85`.

### `setupUI()` — line 225
- **Purpose**: build the entire view hierarchy + constraints + notification observers. See Layout above.
- **Observers registered** (block-based, queue .main): `"Mooziac_LibraryUpdated"`; `HistoryManager.historyUpdatedNotification`; `LikedSongsManager.likedSongsUpdatedNotification`; `DownloadManager.progressNotification`; `DownloadManager.queueNotification`.
- **Reads**: `AppArtworkHelper.defaultArtwork`. **Writes**: all subviews/constraints/state.
- **Side effects**: `searchField.onFocusChange` closure collapses search on blur (0.15s delay, checks firstResponder); `waveformProgressView.onSeek` computes seek seconds; `containerPill.onBackgroundClick` collapses settings on outside click.
- **Potential issue**: the 5 block observers are never removed → if the view is ever re-inited they stack `[I leak]`.

### `setupIconButton(_:systemName:toolTip:action:pointSize:)` — line 530
- Configures an icon `NSButton`: `bezelStyle = .inline`, unbordered, image with symbol config, target/action/tooltip; falls back to `button.title = toolTip` if symbol missing.

### `control(_:textView:doCommandBy:)` — line 545 (NSSearchFieldDelegate)
- Intercepts Enter (`insertNewline:`) in searchField → `searchSubmitted()`, returns `true`.

### `controlTextDidChange(_:)` — line 553 (NSControlTextEditingDelegate)
- If search text contains a link (`URLFilter.containsLink`) → clears field + warning toast "⚠️ Links/URLs are not allowed in search".

### `updateState(_ state: PlaybackState)` — line 571
- **Purpose**: main playback-state → UI binding (called by `NowPlayingManager` presumably on every tick `[I]`).
- **Reads**: `state.title/artist/isPlaying/duration/artworkUrl/isLiked/isRepeatOn`, `NowPlayingManager.shared.engineMode`, `NativeAudioPlayer.shared.currentTrack`, `LyricsManager.cleanSongInfo`.
- **Flow**: detect track change → guard window visible → refresh playlist subview if visible → set title/artist labels (cleaned) or "Not Playing"/"YouTube Music" → swap play/pause icon (diffed via `lastPlayPauseIcon`) → set waveform `isPlaying`/`duration` → if not scrubbing, set `progress` = clamp(`accurateTime/duration`) + `timeLabel` text via `formatTime` → artwork: offline branch uses `NativeAudioPlayer` current track artwork (adds `borderColor white 0.15`), online branch `loadArtwork` if URL changed → like icon if `lastLikeState` differs → repeat: sets `repeatMode` based on `state.isRepeatOn` → `updateDownloadButtonState()`.
- **Outputs**: UI mutations only. **Writes** `lastTrackTitle/Artist/Url`, `lastLikeState`, `isLiked`, `repeatMode`.
- **Side effects**: artwork fetch, playlist refresh, download state refresh. Skips all visual work when window not visible (but still updates track-changed caches before the guard).

### `formatTime(_ seconds: Double) -> String` — line 683
- Guards NaN/inf → "0:00"; returns `"m:ss"` (`%d:%02d`).

### `@objc addToPlaylistButtonTapped()` — line 691
- `animatePop()`; toggles: if settings expanded in `.playlist` mode → `collapseSettings()`; else → `expandAddToPlaylist()`.

### `@objc browserTapped()` — line 700
- `animatePop()`; toggles: expanded `.preferences` → `collapseSettings()`; else → `expandPreferences()`.

### `collapseSettings()` — line 709 (public)
- Guard `isSettingsExpanded` (if already collapsed, hides `settingsContainerView` if still visible and returns). Sets `isSettingsExpanded = false`; pops browser button if in preferences mode; updates button colors; hides settings container; swaps to collapsed bottom constraint; calls `delegate?.dynamicIslandDidToggleExpanded(expanded: false)`.

### `collapseSettingsForOutsideClick()` — line 729 (private)
- Collapses only if expanded in `.preferences` mode (so playlist mode doesn’t dismiss on pill background click).

### `expandPreferences()` — line 735 (public)
- Sets `activeSettingsMode = .preferences`, `showMainSettingsView()`, `expandSettingsPanel()`.

### `expandAddToPlaylist()` — line 741 (public)
- Sets `activeSettingsMode = .playlist`, `showAddToPlaylistSubView()`, `expandSettingsPanel()`.

### `expandSettingsPanel()` — line 747 (private)
- If already expanded: refresh colors/highlight, return. Else set expanded, update colors/highlight, activate settings bottom constraint, `delegate?.dynamicIslandDidToggleExpanded(expanded: true)`, then after 0.15s reveal `settingsContainerView`.

### `flashGlowOnButton()` — line 769
- CABasicAnimation shadow glow (0.18s, autoreverse, toValue 0.9, radius 7) + scale pulse (0.12s to 1.25) on `addToPlaylistButton.layer`. **No callers in these files** `[I dead]`.

### `@objc repeatTapped()` — line 800
- `animatePop()`; toggles `repeatMode` off↔one; `updateRepeatButtonColor()`; **`NowPlayingManager.shared.setRepeatMode(repeatMode)`**; shows overlay `CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text: repeatMode.displayName)`.
- **Note**: repeat does NOT go through the delegate despite `dynamicIslandDidTapRepeat()` existing.

### `@objc previousTapped()` — line 808
- `previousButton.animateBounce(direction: -1.0)`; `delegate?.dynamicIslandDidTapPrevious()`.

### `@objc nextTapped()` — line 813
- `animateBounce(direction: 1.0)`; `delegate?.dynamicIslandDidTapNext()`.

### `@objc searchIconTapped()` — line 819
- If search hidden or alpha < 0.5 → `expandSearchField()`; else `collapseSearchField()`.

### `expandSearchField()` — line 827
- Reveal: unhide field, set `xmark` icon, animate 0.30s: deactivate `controlsStackCenterX`, activate `controlsStackLeading`, field alpha → 1.0; completion: make firstResponder.

### `collapseSearchField()` — line 854
- Guard `!isCollapsingSearch`; set flag; restore `magnifyingglass` icon; resign first responder if needed; animate 0.28s reverse; completion: hide field, clear flag.

### `@objc networkStatusChanged(_ note: Notification)` — line 884
- Reads `note.userInfo?["isReachable"]`; toast "⚡ Offline Mode - No Internet Connection" (warning) or "🟢 Internet Connection Restored!".

### `showToastBanner(message:isWarning:)` — line 893 (public)
- DispatchQueue.main.async: invalidate prior timer; set label text; set border color (warning red vs success green); reveal with 0.25s fade; schedule auto-dismiss Timer 2.8s → fade out 0.25s → hide.
- **Side effects**: allocates Timer; called from many places.

### `@objc searchSubmitted()` — line 921
- Trim query; reject links; reject if offline (`NetworkMonitor.shared.isReachable` false) with toast; clear field; `collapseSearchField()`; resign responder; if non-empty → `delegate?.dynamicIslandDidSearch(query:)`.

### `@objc playPauseTapped()` — line 940
- `animatePop()`; optimistic icon flip from `NowPlayingManager.shared.currentState.isPlaying`; `delegate?.dynamicIslandDidTapPlayPause()`.

### `@objc likeTapped()` — line 953
- Toggles `isLiked`, sets `lastLikeState`; `likeButton.animateHeartPop()`; icon swap `heart`/`heart.fill`; `updateLikeButtonColor()`; **`NowPlayingManager.shared.toggleLike()`**.

### `updateDownloadButtonState()` — line 966 (public)
- Reads current state; if no track → `.idleDownload`. If `engineMode == .offline` → `.completed`. Computes clean title/artist, `vid` from `state.videoId` or `DownloadManager.extractVideoID(from: state.pageUrl)`; checks `LocalLibraryManager.shared.allTracks` for existing download (vid match OR title/artist match); else `DownloadManager.shared.statusFor(id:vid)` maps `.queued/.downloading(progress,eta)/.completed/.failed → .idleDownload`; sets `downloadButton.downloadState` + tooltip ("Download Song"/"Downloaded (Available Offline)"/queue tooltip).
- **Reads**: many managers. **Side effects**: UI only.

### `@objc downloadCurrentTrackTapped()` — line 1016
- Guards active track (toast "⚠️ Nothing playing right now"); offline-mode toast "✓ Currently playing offline track"; computes `idToUse` (`vid` else `"\(cleanT)_\(cleanA)"`); switch on `downloadButton.downloadState`: queued/downloading → `DownloadManager.shared.cancelTask(id:)` + set `.idleDownload`; completed → no-op; idle/unavailable → `DownloadManager.shared.queueTrack(id:urlOrVideoId:title:artist:artworkUrl:)` with completion → main-async toast on failure + `updateDownloadButtonState()`.
- **Async**: queueTrack completion on background queue, marshalled via DispatchQueue.main.

### `@objc offlineLibraryTapped()` — line 1059
- `collapseSettings()`; `delegate?.dynamicIslandDidTapOfflineLibrary()`. **No button in Core.swift wires this** — selector may be referenced from SettingsPanel rows elsewhere `[I]`.

### `@objc fullScreenTapped()` — line 1064
- `animatePop()`; `collapseSettings()`; `delegate?.dynamicIslandDidTapWebBrowser()`.

### `updateBrowserButtonColor()` — line 1070
- Cyan when settings expanded in preferences; glass `(0.082,0.082,0.082)`; adaptive/native `white 0.80`; darkMode `white 0.85`.

### `updateAddToPlaylistButtonColor()` — line 1085
- Same palette logic keyed on `.playlist` mode.

### `@objc resetPositionTapped()` — line 1100
- `animateSpinPop()`; `delegate?.dynamicIslandDidTapResetPosition()`.

### `setResetPositionButtonHidden(_:)` — line 1105 (public)
- Guard change; animate `animator().isHidden` over 0.25s.

### `resetCursorRects()` — line 1113 (override)
- Forces arrow cursor over the whole view.

### `mouseDown(with:)` — line 1118 (override)
- **Double-click** (clickCount == 2): toggles preferences drawer (collapse if expanded-preferences, else `expandPreferences()`).
- **Single click while expanded**: converts location; if inside settings frame → pass through; if outside both settings frame and the browser/addToPlaylist button frames → `collapseSettings()`; else pass through.

### `acceptsFirstResponder` — line 1144 (override) → `true`.

### `keyDown(with:)` — line 1148 (override)
- If first responder is a text-ish view → pass to super. Else `KeyboardCommandHandler.handle(keyCode:isRepeat:showOverlay:)` where overlay closure → `CenteredMenuBarLyricsWindowController.shared.showCustomTextOverlay(text:)`; if handled return, else super.

## CLASS ENTRY — `final class PillContainerView: NSView`

- **Purpose**: Hit-test container for the pill. Only swallows clicks on its own background (not on child controls).
- **Properties**: `var onBackgroundClick: (() -> Void)?`.
- **`mouseDown(with:)`** (line 1170): if `hitTest(localPoint) == self` (i.e., click hit the container’s own background) → `onBackgroundClick?()`.
- **Consumers**: DynamicIslandPlayerView sets `onBackgroundClick` = `collapseSettingsForOutsideClick()` (line 289).

---

# FILE 2 — `Views/Player/DynamicIslandPlayerView/SettingsPanel.swift` (3546 lines)

## FILE ENTRY

- **File path**: `Sources/Mooziac/Views/Player/DynamicIslandPlayerView/SettingsPanel.swift`
- **Purpose**: `extension DynamicIslandPlayerView` implementing the entire settings drawer: preferences tab (theme, progress style, feature toggles), the "Add to Playlist" mini library (playlists / liked songs / downloads / history tabs, playlist detail, inline create, search, selection & bulk delete, swipe-to-delete rows, context menus, drag-to-reorder), plus the private row-view classes used by the drawer.
- **Subsystem**: Views → Player → DynamicIslandPlayerView (drawer subsystem).
- **Dependencies**: PlaylistManager, LikedSongsManager, DownloadManager, HistoryManager, LocalLibraryManager, LocalDatabaseManager, NowPlayingManager, NativeAudioPlayer, LyricsManager, PlayerDesign, ProgressStyle, AppVolumeManager, EdgeVolumeEngine, DiscordRPCManager, CenteredMenuBarLyricsWindowController, GlassSearchField, NativeCapsuleToggleView, ReactiveIconButton, CircularProgressDownloadButton, SwipeToDeleteContainerView, SettingsTone, PlayerDesign.
- **Imports**: `AppKit`.
- **Classes defined** (all `private` unless noted):
  - (extension of DynamicIslandPlayerView)
  - `SettingsFlippedDocView` (private, line 2769)
  - `SettingsFlippedClipView` (private, line 2773)
  - `DownloadRowView` (private, line 2778)
  - `LibraryNavButton: NSControl` (line 2881)
  - `DetailItemRowView` (private, line 3022)
  - `VerticalPanGestureRecognizer` (private, line 3254)
  - `HistoryRowView` (private, line 3292)
  - `LikedSongRowView` (private, line 3460)
  - free function `rowPlayIconColor(tone:)` (private, line 3015)
- **Magic constants** (`[V]`): settings container fixed height 295 (Core); search expand width 165; create field width 175; animation 0.22s; row heights 34 (playlist) / 40 (detail, download, history, liked, add-song); libraryNavButton height 26; subHeaderStack height 24; dedicatedActionRow height 26; search/create field height 24; cyan accent `(0, 0.85, 1.0)` glass-variant `(0, 0.50, 0.90)`; destructive red `(0.95, 0.35, 0.35)`; confirm green `(0.18, 0.80, 0.44)`.
- **Events**: observes `DownloadManager.progressNotification` (in DetailItemRowView & HistoryRowView); posts `LikedSongsManager.likedSongsUpdatedNotification` (in `removeLikedSong`).
- **UserDefaults keys**: none read/written directly in this file; indirect through managers (e.g., `YTM_playerDesign` via `PlayerDesign.current`, `YTM_progressStyle` via `ProgressStyle.current`).
- **Side effects**: NSAlert modal dialogs (delete/bulk-delete/name prompts); NSOpenPanel (import); Finder reveal via `NSWorkspace`; heavy list re-renders (`refreshPlaylistsSection` clears & rebuilds stack).

## SETTINGS STRUCTURE (setupSettingsContainerView, line 5)

**`settingsContainerView`** contains two sibling views toggled by identifier:
- **`MainSettingsStack`** (NSStackView, identifier `"MainSettingsStack"`): vertical of `featuresSectionLabel` ("PLAYER PREFERENCES") + `featuresStack` with rows:
  1. **themeRow** (`makeThemeFeatureRow`) — icon `paintbrush.fill`; title "Player Theme"; desc = `currentThemeDisplayName()`; cycle button (`arrow.triangle.2.circlepath`, tooltip "Change Player Theme") → `themeCycleTapped`.
  2. **progressRow** (`makeProgressStyleFeatureRow`) — icon `waveform.path.ecg`; title "Progress Bar"; desc = `ProgressStyle.current.displayName`; cycle button → `progressStyleCycleTapped`.
  3. **volumeRow** — `makeFeatureRow(icon: "speaker.wave.2.fill", title: "App-Only Sound", description: "Control media sound alone, not system", isOn: AppVolumeManager.shared.isAppVolumeOnly, toggle: appVolumeToggle, onToggle: { AppVolumeManager.shared.isAppVolumeOnly = $0 })`.
  4. **gesturesRow** — `makeFeatureRow(icon: "hand.tap", title: "Master Gestures", description: "Swipe, pinch & tap controls", isOn: EdgeVolumeEngine.shared.isEnabled, toggle: masterGesturesToggle, onToggle: { EdgeVolumeEngine.shared.isEnabled = $0 })`.
  5. **lyricsRow** — `makeFeatureRow(icon: "quote.bubble", title: "Lyrics", description: "Show synced lyrics", isOn: CenteredMenuBarLyricsWindowController.shared.isEnabled, toggle: lyricsToggle, onToggle: { CenteredMenuBarLyricsWindowController.shared.isEnabled = $0 })`.
  6. **discordRow** — `makeFeatureRow(icon: "number", title: "Discord Rich Presence", description: "Share what you're listening to", isOn: DiscordRPCManager.shared.isEnabled, toggle: discordToggle, onToggle: { DiscordRPCManager.shared.isEnabled = $0 })`.
- **`PlaylistSubView`** (NSView, identifier `"PlaylistSubView"`, hidden by default): the mini library. Structure:
  - `topControlsStack` (vertical): `subHeaderStack` (`playlistDetailBackButton` + `playlistSectionLabel` ("PLAYLISTS") + spacer), `libraryNavContainer` (horizontal `libraryNavStack` of `LibraryNavButton`s, fillEqually, spacing 4), `dedicatedActionRow` (left: `playlistSearchToggleButton` + `playlistSearch` field; right: `actionsTrailingStack` = inlineCreateContainer, create, import, play-all, shuffle, bulk-delete, selection-done, detail play-all, detail shuffle, detail download-all, detail add, detail delete).
  - `playlistScroll` (NSScrollView, no scrollers, transparent) with flipped clip/doc views containing `playlistsStackView` + hidden `detailStackView`.

**Right-click context menus**: per row type via `override func menu(for event:)` delegating to:
- `contextMenu(for track: LocalTrack)` — "Download Options": Play Track, Play Next, Add to Queue, "Add to Playlist" submenu (+ New Playlist…), Like/Unlike, Show in Finder, Delete Download.
- `contextMenu(for record: LikedSongRecord)` — "Liked Song Options": Play Track, Play Next, Add to Queue, Add to Playlist submenu, Download Track (if not downloaded & has vid), Show in Finder (if downloaded), Remove from Liked Songs.
- `contextMenu(for record: HistoryRecord)` — "History Options": Play Track, Play Next, Add to Queue, Add to Playlist submenu, Download Track (online source w/ vid), Remove from History.
- `contextMenu(for item: PlaylistItemRecord)` — "Playlist Track Options": Play Track, Play Next, Add to Queue, "Copy to Playlist" submenu (excludes current playlist), Download Track (if online resolution), Remove from Playlist.

## FUNCTION ENTRIES — SettingsPanel.swift (extension)

### `setupSettingsContainerView()` — line 5
Builds everything above; wires all buttons/actions; calls `showMainSettingsView()` + `updateSettingsThemeHighlight()`. **Reads**: all manager enable states; `currentSettingsTone()`. **Writes**: entire sub-hierarchy + anchors (search width 0 / create width 0 initially).

### `@objc private handleClosePlaylistPanel()` — line 524 → `collapseSettings()`. **No wire-up found** `[I dead]`.

### `showMainSettingsView()` — line 528 (public)
Unhides `MainSettingsStack`, hides `PlaylistSubView`, shows header label.

### `showAddToPlaylistSubView()` — line 538 (public)
Hides main stack, shows `PlaylistSubView`, hides header; resets `playlistDetailMode = nil`, `playlistAddMode = false`, `isPlaylistSearchActive = false`, `isPlaylistCreateOpen = false`; `resetPlaylistSectionChrome()`, `applySearchCreateFieldState(animated: false)`, `refreshPlaylistsSection()`, `updateSettingsThemeHighlight()`.

### `selectLibraryTab(_ tab: LibraryTab)` — line 556 (private)
Guard change; set `activeLibraryTab`; reset search/create/selection state + `selectedPlaylistIDs`; clear search/create text; `resetPlaylistSectionChrome()`, `applySearchCreateFieldState(animated: false)`, `refreshPlaylistsSection()`, `updateSettingsThemeHighlight()`.

### `@objc private handleLibraryNavTapped(_ sender: LibraryNavButton)` — line 571
`selectLibraryTab(sender.libraryTab)`.

### `resetPlaylistSectionChrome()` — line 575 (private)
Toggles visibility of header/nav/action buttons based on `playlistDetailMode` and `activeLibraryTab`. Two big branches:
- **Detail mode**: header shows playlist name (uppercased); back button visible; create/search-toggle/bulk/done hidden; if `playlistAddMode` hides all detail actions + search placeholder "Search all songs..."; else shows delete/add/play-all/shuffle/download-all; `playlistsStackView.hidden = true`, `detailStackView.hidden = false`. Detail search placeholder "Search `<name>`...".
- **List mode**: per tab:
  - `.playlists`: create + search-toggle visible; bulk/done only in selection mode; placeholder "Search playlists...".
  - `.likedSongs`: search-toggle only; placeholder "Search liked songs...".
  - `.downloads`: search-toggle + import + play-all + shuffle; placeholder "Search downloaded tracks...".
  - `.history`: search-toggle only; placeholder "Search listening history...".
- Ends with `updatePlaylistSearchToggleIcon()` + `updatePlaylistCreateButtonIcon(isCreating:)`.

### `applySearchCreateFieldState(animated:)` — line 685 (private)
Derives mutual-exclusive search/create open state (detail forces search open); calls the four expand/collapse field helpers.

### `expandSearchField(animated:)` / `collapseSearchField(animated:)` / `expandCreateField(animated:)` / `collapseCreateField(animated:)` — lines 707/721/737/751 (private)
Animate width anchors to 165 (search) / 175 (create) over 0.22s; collapse hides the view in completion.

### `@objc private handlePlaylistSearchChanged(_ sender: NSSearchField)` — line 767
`refreshPlaylistsSection(filterQuery: sender.stringValue)`.

### `updatePlaylistSearchToggleIcon()` — line 771
Sets `magnifyingglass` icon + tooltip reflecting `isPlaylistSearchActive`.

### `@objc private handlePlaylistSearchToggle()` — line 777
Closes create if open; toggles `isPlaylistSearchActive`; when activating: leaves selection mode, clears query, `expandSearchField(animated: true)`, focus field; when deactivating: clears query, resign responder, collapse, refresh.

### `@objc private handleTogglePlaylistSelectionMode()` — line 805
Toggles selection mode; clears `selectedPlaylistIDs` when leaving; closes search; refresh + highlight.

### `@objc private handlePlaylistContextSelect(_ sender: NSMenuItem)` — line 822
Enters selection mode if needed; toggles playlist id in `selectedPlaylistIDs`; refresh + highlight.

### `@objc private handlePlaylistContextDelete(_ sender: NSMenuItem)` — line 844
Looks up playlist by `representedObject` id → `confirmAndDeletePlaylistFromRow(_:)`.

### `@objc private handleBulkDeletePlaylists()` — line 850
Guards selection; NSAlert "Delete Playlists" (destructive Delete / Cancel); on confirm loops `PlaylistManager.shared.deletePlaylist(id:)`, clears selection, exits selection mode, toast "🗑 Deleted N playlists", refresh + highlight.

### `refreshPlaylistsSection(filterQuery: String = "")` — line 876 (public)
- Clears both stacks; resets chrome; tone = `currentSettingsTone()`.
- **Detail mode** → `renderPlaylistDetail(...)`, return.
- **List mode** by tab, all with lowercased substring filter:
  - `.playlists`: `PlaylistManager.shared.fetchPlaylists()` → `makePlaylistRow`.
  - `.likedSongs`: `LikedSongsManager.shared.fetchLikedSongs()` → `makeLikedSongRow`.
  - `.downloads`: `LocalLibraryManager.shared.allTracks` → `makeDownloadRow`.
  - `.history`: `HistoryManager.shared.fetchHistory()` → `makeHistoryRow`.
- Empty states show `NSTextField` messages ("No playlists yet. Click '＋ Create' to make one.", "No liked songs yet. Tap the ♥ on any track to save it here.", "No downloaded tracks yet", "No listening history yet", plus "No matching … found" variants).
- **Reads**: all four managers. **Side effects**: full rebuild of stack views; scroll reset to top.

### `renderPlaylistDetail(_ playlist: PlaylistRecord, tone: SettingsTone, filterQuery: String)` — line 993 (private)
- Items = `PlaylistManager.shared.fetchPlaylistItems(playlistID:)`.
- Header chrome (back visible, etc.). **Add-mode** (`playlistAddMode`): hides all actions; lists addable local tracks (`LocalLibraryManager.shared.allTracks` minus already-in-playlist, matched by `ytVideoId` or `fileURL.path`), filtered by query; `makeAddSongRow`. **Normal**: shows play-all/shuffle/download-all; filters items by query; `makeDetailItemRow`.
- Empty messages: "Empty playlist"/"No matching songs found"/"No more songs to add"/"No matching songs found".

### `makePlaylistRow(playlist:tone:)` — line 1093 (private) → `SwipeToDeleteContainerView`
- Row height 34, cornerRadius 14; content card with emoji-prefixed title (`PlaylistManager.metaFor(playlistName:)`) + count ("Empty" / "N tracks") + chevron.
- **Selection mode**: checkbox icon (checkmark.circle.fill / circle), delete/play swipes disabled; `onRowClicked` toggles selection.
- **Normal**: `onRowClicked` opens detail (sets `playlistDetailMode`, resets flags, refresh); `onDelete` → `confirmAndDeletePlaylistFromRow`; `onRightSwipePlay` → if empty toast "⚠️ \"<name>\" is empty" (return false), else `PlaylistManager.shared.startPlaylist(playlistID:startingAt:nil,shuffle:false)` + toast "▶ Playing \"<name>\"".
- **Context menu**: "Select" (state = on/off) + "Delete" items with `representedObject = playlist.id`.

### `confirmAndDeletePlaylistFromRow(_:)` — line 1248 (private)
NSAlert (destructive Delete/Cancel); on confirm `PlaylistManager.shared.deletePlaylist(id:)`; if deleting the open detail playlist, exit detail; toast "🗑 Deleted \"<name>\""; refresh + highlight.

### `makeDetailItemRow(item:index:total:tone:)` — line 1270 (private)
`SwipeToDeleteContainerView` (deleteButtonTitle "Remove", height 40) containing `DetailItemRowView`; `onDelete` → `removeItemFromPlaylist(item)`.

### `removeItemFromPlaylist(_ item:)` — line 1296 (private)
`PlaylistManager.shared.removeItem(itemID:from:)`; toast "🗑 Removed \"<title>\""; refresh + highlight.

### `makeAddSongRow(track:tone:)` — line 1304 (private)
Plain row (title/artist + plus `ReactiveIconButton` targeting `handleAddSongTrack(_:)`; glass uses blue `(0,0.50,0.90)` accent).

### `makeDownloadRow(track:allTracks:tone:)` — line 1366 (private)
`SwipeToDeleteContainerView` wrapping `DownloadRowView`; `onDelete` → `confirmAndDeleteDownloadedTrack`.

### `makeHistoryRow(record:tone:)` — line 1392 (private)
`SwipeToDeleteContainerView` wrapping `HistoryRowView`; `onDelete` → `removeHistoryRecord`.

### `removeHistoryRecord(_ record:)` — line 1418 (private)
`HistoryManager.shared.deleteHistoryItem(id:)`; toast "🗑 Removed from history"; refresh.

### `makeLikedSongRow(record:tone:)` — line 1424 (private)
`SwipeToDeleteContainerView` wrapping `LikedSongRowView`; `onDelete` → `removeLikedSong`.

### `removeLikedSong(_ record:)` — line 1450 (private)
`LocalDatabaseManager.shared.removeLikedSong(videoId:)`; **posts** `LikedSongsManager.likedSongsUpdatedNotification`; toast "♥ Removed from liked songs"; refresh.

### `@objc handlePlayLikedSong(_ sender: ReactiveIconButton)` — line 1457
Resolve local track via `LocalLibraryManager.shared.allTracks` (by `ytVideoId` or `fileURL.path == videoId`) → `NowPlayingManager.shared.playOfflineTrack(localTrack, in: allTracks)`; else if vid non-empty → `NowPlayingManager.shared.switchToOnlineMode()` + `PlaylistManager.shared.playOnlineVideo(videoId:)`; toast "▶ Playing \"<title>\"". **Note**: local branch passes the FULL `allTracks` as queue — play-next semantics `[I]`.

### `@objc handlePlayDownloadedTrack(_ sender:)` — line 1473
`playOfflineTrack(track, in: allTracks)`; toast.

### `confirmAndDeleteDownloadedTrack(_ track:)` — line 1479 (private)
NSAlert; on confirm `LocalLibraryManager.shared.deleteTrack(track) { success in ... }` → main-async toast + refresh + `updateDownloadButtonState()`.

### `@objc handleDownloadsImportTapped()` — line 1500
NSOpenPanel (files+dirs, multiple, `.audio`/`.mp3`, prompt "Import Music"); on OK → `LocalLibraryManager.shared.importFiles(from: panel.urls) { count in ... }` → toast "✓ Imported N audio track(s)", refresh, `updateDownloadButtonState()`.

### `@objc handleDownloadsPlayAllTapped()` — line 1521
Guard non-empty; `playOfflineTrack(tracks[0], in: tracks)`; toast "▶ Playing all downloaded tracks".

### `@objc handleDownloadsShuffleTapped()` — line 1531
Guard; `playOfflineTrack(shuffled[0], in: shuffled)`; toast "🔀 Shuffling downloaded tracks".

### `contextMenu(for track: LocalTrack) -> NSMenu` — line 1544
Builds "Download Options" menu (see structure above). Items' `representedObject` = track / `["track": …, "playlistID": …]`. Selectors: `handleDrawerPlayDownloadItem`, `handleDrawerPlayNextDownloadItem`, `handleDrawerAddToQueueDownloadItem`, `handleDrawerAddDownloadToPlaylist`, `handleDrawerNewPlaylistWithDownload`, `handleDrawerToggleLikeDownloadItem`, `handleDrawerShowDownloadInFinder`, `handleDrawerDeleteDownloadItem`.

### `contextMenu(for record: LikedSongRecord) -> NSMenu` — line 1616
"Liked Song Options". Selectors: `handleDrawerPlayLikedSongItem`, `handleDrawerPlayNextLikedSongItem`, `handleDrawerAddToQueueLikedSongItem`, `handleDrawerAddLikedSongToPlaylist`, `handleDrawerNewPlaylistWithLikedSong`, `handleDrawerDownloadLikedSongItem`, `handleDrawerShowDownloadInFinder`, `handleDrawerDeleteLikedSongItem`.

### `contextMenu(for record: HistoryRecord) -> NSMenu` — line 1699
"History Options". Selectors: `handleDrawerPlayHistoryItem`, `handleDrawerPlayNextHistoryItem`, `handleDrawerAddToQueueHistoryItem`, `handleDrawerAddHistoryToPlaylist`, `handleDrawerNewPlaylistWithHistory`, `handleDrawerDownloadHistoryItem`, `handleDrawerDeleteHistoryItem`.

### `contextMenu(for item: PlaylistItemRecord) -> NSMenu` — line 1765
"Playlist Track Options". Selectors: `handleDrawerPlayPlaylistItem`, `handleDrawerPlayNextPlaylistItem`, `handleDrawerAddToQueuePlaylistItem`, `handleDrawerCopyPlaylistItemToPlaylist`, `handleDrawerNewPlaylistWithPlaylistItem`, `handleDrawerDownloadPlaylistItem`, `handleDrawerDeletePlaylistItem`. Download shown only when `PlaylistManager.shared.resolve(item)` is `.online`.

### Drawer context-menu action handlers (lines 1834–2145, all `@objc private`)

| Selector | Line | Effect |
|---|---|---|
| `handleDrawerPlayDownloadItem` | 1834 | `NowPlayingManager.shared.playOfflineTrack(track, in: allTracks)`; toast "▶ Playing …" |
| `handleDrawerPlayNextDownloadItem` | 1840 | `NativeAudioPlayer.shared.playNext(track:)`; toast "⏭ Playing Next: …" |
| `handleDrawerAddToQueueDownloadItem` | 1846 | `NativeAudioPlayer.shared.appendToQueue(track:)`; toast "➕ Added to Queue: …" |
| `handleDrawerAddDownloadToPlaylist` | 1852 | `PlaylistManager.shared.appendTrack(to:track:)`; toast success/`res.message`; refresh |
| `handleDrawerNewPlaylistWithDownload` | 1866 | `promptForDrawerPlaylistName` default "`<title>` Playlist"; `createPlaylist` + `appendTrack`; toast; refresh |
| `handleDrawerToggleLikeDownloadItem` | 1878 | `LocalLibraryManager.shared.toggleLike(for: track.id)`; toast (reads stale `track.isLiked` before toggle `[I bug candidate]`); refresh |
| `handleDrawerShowDownloadInFinder` | 1885 | Reveal `track.fileURL` in Finder if exists else `openMusicFolderInFinder()` |
| `handleDrawerDeleteDownloadItem` | 1894 | `confirmAndDeleteDownloadedTrack` |
| `handleDrawerPlayLikedSongItem` | 1899 | builds fake `ReactiveIconButton` → `handlePlayLikedSong` |
| `handleDrawerPlayNextLikedSongItem` | 1906 | synthesizes `PlaylistItemRecord` (refType "yt", refID=videoId) → `PlaylistManager.shared.playNext(item:)`; toast |
| `handleDrawerAddToQueueLikedSongItem` | 1924 | same synthesis → `addToQueue(item:)`; toast |
| `handleDrawerAddLikedSongToPlaylist` | 1942 | `PlaylistManager.shared.appendLikedSong(to:record:)`; toast; refresh |
| `handleDrawerNewPlaylistWithLikedSong` | 1956 | prompt → `createPlaylist` + `appendLikedSong`; toast; refresh |
| `handleDrawerDownloadLikedSongItem` | 1968 | `DownloadManager.shared.downloadTrack(urlOrVideoId:record.videoId, ...)`; toast "⬇ Queued download: …"; refresh in completion |
| `handleDrawerDeleteLikedSongItem` | 1983 | `removeLikedSong(record)` |
| `handleDrawerPlayHistoryItem` | 1988 | fake button → `handlePlayHistoryRecord` |
| `handleDrawerPlayNextHistoryItem` | 1995 | synthesizes `PlaylistItemRecord` (refType local/online) → `playNext(item:)`; toast |
| `handleDrawerAddToQueueHistoryItem` | 2013 | synthesis → `addToQueue(item:)`; toast |
| `handleDrawerAddHistoryToPlaylist` | 2031 | `appendHistoryItem(to:item:)`; toast; refresh |
| `handleDrawerNewPlaylistWithHistory` | 2045 | prompt → `createPlaylist` + `appendHistoryItem`; toast; refresh |
| `handleDrawerDownloadHistoryItem` | 2057 | fake button → `handleDownloadHistoryButtonTapped` |
| `handleDrawerDeleteHistoryItem` | 2064 | `removeHistoryRecord(record)` |
| `handleDrawerPlayPlaylistItem` | 2069 | `startPlaylist(playlistID:startingAt:item.id,shuffle:false)` |
| `handleDrawerPlayNextPlaylistItem` | 2075 | `playNext(item:)`; toast |
| `handleDrawerAddToQueuePlaylistItem` | 2081 | `addToQueue(item:)`; toast |
| `handleDrawerCopyPlaylistItemToPlaylist` | 2087 | deep-copies `PlaylistItemRecord` → `appendPlaylistItem(newItem, to:)`; toast |
| `handleDrawerNewPlaylistWithPlaylistItem` | 2108 | prompt → `createPlaylist` + copy `appendPlaylistItem`; toast; refresh |
| `handleDrawerDownloadPlaylistItem` | 2132 | fake button → `handleDownloadDetailItem` |
| `handleDrawerDeletePlaylistItem` | 2139 | `PlaylistManager.shared.removeItem(itemID:from:playlist.id)`; toast; refresh |

### `promptForDrawerPlaylistName(title:defaultName:completion:)` — line 2147 (private)
NSAlert with `NSTextField` accessory (240×24, initial first responder); on "Create" trims → `completion(name.isEmpty ? "My Playlist" : name)`.

### `@objc handlePlayHistoryRecord(_ sender:)` — line 2168
`HistoryManager.shared.playHistoryItem(record)`; toast "▶ Playing \"<title>\"".

### `@objc handleDownloadHistoryButtonTapped(_ sender:)` — line 2174
Per `btn.downloadState`: queued/downloading → `cancelTask(id: record.id)` + `.idleDownload` + toast "✕ Cancelled download"; completed → toast "✓ \"<title>\" is already saved offline"; idle/unavailable → `queueTrack(id: record.id, urlOrVideoId: vid.isEmpty ? "\(record.title) \(record.artist)" : vid, ...)`; completion: success → "✓ Saved \"<title>\" offline" else warning `message`; refresh + `updateDownloadButtonState()`.

### `@objc private handlePlayPlaylistFromRow` / `handleShufflePlaylistFromRow` — lines 2209/2216
`PlaylistManager.shared.play(playlistID:) { res in toast }` / `.shufflePlay(playlistID:) { res in toast }`; toast shows `res.message`, warning when `!res.started`.

### `@objc private handleTogglePlaylistRow` — line 2223
`PlaylistManager.shared.toggleCurrentPlayingTrack(in:)`; toast "✓ Added to X" / "✕ Removed from X"; refresh + highlight. **No wire-up in these files** `[I dead]`.

### `@objc private handleOpenFullPlaylistLibrary` — line 2231
`collapseSettings()`; `delegate?.dynamicIslandDidTapPlaylistLibrary(playlistID: nil)`. **No wire-up in these files** `[I dead]`.

### `@objc private handleOpenPlaylistDetail(_ sender: NSClickGestureRecognizer)` — line 2236
Resolves playlist via `sender.view?.identifier?.rawValue`; opens detail. **No recognizer wiring in these files** `[I dead]`.

### `@objc private handleBackFromPlaylistDetail()` — line 2249
If add-mode → exit add-mode only; else exit detail, clear search, refresh.

### `@objc private handlePlayPlaylistFromDetail()` / `handleShufflePlaylistFromDetail()` — lines 2268/2275
Same as row versions but using `playlistDetailMode`.

### `@objc handlePlayItemFromDetail(_ sender:)` — line 2282
`startPlaylist(playlistID:startingAt:item.id,shuffle:false)`.

### `@objc handleDownloadDetailItem(_ sender:)` — line 2288
`vid = item.ytVideoId ?? item.refID`; guard non-empty; toast "⬇ Added ..."; `queueTrack(id: item.id, urlOrVideoId: vid, ...)`; completion: success → "✓ Saved ... offline" else warning; refresh.

### `@objc handleDownloadButtonTapped(_ sender:)` — line 2313
Switch on `btn.downloadState` (item): queued/downloading → cancel + `.idleDownload` + toast; idle → `handleDownloadDetailItem`; completed → `handleDownloadedItemClicked`; unavailable → no-op.

### `@objc handleDownloadedItemClicked(_ sender:)` — line 2331
Toast "✓ \"<title>\" is already saved offline".

### `@objc private handleDownloadAllFromDetailHeader()` — line 2336
`plan = PlaylistManager.shared.planDownloads(for: playlist.id)`; if nothing to download: offline-blocked → warning "⚠️ You're offline — go online to download N track(s)"; else "✓ All tracks are already downloaded". Else toast "⬇ Queued N tracks from \"<name>\""; `DownloadManager.shared.queueTracks(tuples)` where vid = `ytVideoId ?? refID`.

### `@objc private handleAddSongTrack(_ sender:)` — line 2356
`PlaylistManager.shared.appendLocalTracks([track], to: playlist.id)`; toast "✓ Added \"<title>\"", refresh, highlight.

### `@objc private handleAddToPlaylistRow(_ sender:)` — line 2365
`appendCurrentPlayingTrack(to:)`; toast success / `result.message`; refresh + highlight. **No wire-up in these files** `[I dead]`.

### `updatePlaylistCreateButtonIcon(isCreating:)` — line 2377
Sets `plus` icon; tooltip "Cancel" vs "Create New Playlist".

### `@objc private handleCreateNewPlaylistFromHeader()` — line 2383
If create open → `handleInlineCreateCancel()`. Else close search; set `isPlaylistCreateOpen = true`; clear field; `expandCreateField(animated: true)`; focus field.

### `@objc private handleInlineCreateConfirm()` — line 2404
Trim name; empty → `handleInlineCreateCancel()`; else `isPlaylistCreateOpen = false`, collapse create field, resign responder, `createPlaylist(name:)` → toast "✓ Created \"<name>\"", refresh + highlight.

### `@objc private handleInlineCreateCancel()` — line 2422
Reset create state; collapse field; refresh + highlight.

### `@objc private handleDeletePlaylistFromHeader()` — line 2433
NSAlert confirm; `deletePlaylist(id:)`; exit detail; clear search; refresh + highlight.

### `@objc private handleAddCurrentSongToDetailPlaylist()` — line 2454
`appendCurrentPlayingTrack(to: playlist.id)`; toast success / warning; refresh + highlight.

### `currentThemeDisplayName() -> String` — line 2466
`.glassMode` → "Crystal Glass (Light)"; `.adaptive/.native` → "Adaptive (System)"; `.darkMode` → "OLED Dark".

### `makeThemeFeatureRow() -> NSView` — line 2474
Row (height 32): `paintbrush.fill` icon 16pt, "Player Theme" + desc (stored to `themeDescLabel`), cycle button (28×22) → `themeCycleTapped`. Appends to `featureIconViews/titleLabels/descLabels`.

### `@objc themeCycleTapped()` — line 2544
Cycles `PlayerDesign.current` glass→adaptive→darkMode→glass; overlay toast "Theme: Adaptive"/"Theme: OLED Dark"/"Theme: Crystal Glass"; `applyTheme()`; updates `themeDescLabel`; `updateSettingsThemeHighlight()`.
- **Side effect**: `PlayerDesign.current` setter posts `"YTM_playerDesignChanged"` → global re-theme.

### `makeProgressStyleFeatureRow() -> NSView` — line 2561
`waveform.path.ecg` icon; desc from `ProgressStyle.current.displayName` (→ `progressDescLabel`); cycle button → `progressStyleCycleTapped`.

### `@objc progressStyleCycleTapped()` — line 2631
`next = all[(idx+1) % all.count]`; `ProgressStyle.current = next` (setter posts `"ProgressStyleDidChange"` + writes `YTM_progressStyle` & `YTM_v3_useWaveformProgress`); updates label; `waveformProgressView.needsDisplay = true`; overlay toast "Progress Bar: <name>".

### `makeFeatureRow(icon:title:description:isOn:toggle:onToggle:) -> NSView` — line 2642
Generic toggle row (height 32): icon, title, desc, `NativeCapsuleToggleView` (32×18) with `isOn` + `onToggle` closure (wired to manager setters at call sites).

### `currentSettingsTone() -> SettingsTone` — line 2705
`.darkMode` → `.dark`; `.glassMode` → `.light`; `.adaptive/.native` → dark/light from `NSApp.effectiveAppearance.bestMatch`.

### `updateSettingsThemeHighlight()` — line 2718
Recolors header labels, feature icons/titles/descs from tone; refreshes `themeDescLabel`; applies playlist search style; resets nav container; recomputes cyan (glass `(0,0.50,0.90)` else `(0,0.85,1.0)`); `libraryNavButtons.refresh(tone:isGlass:cyan:)`; re-tints all drawer action buttons; sets `playlistDetailCreateButton` cyan when create open; re-tints import/play-all/shuffle/search-toggle/bulk/done; styles inline create container.

## CLASS ENTRY — `private class SettingsFlippedDocView: NSView` (line 2769)
- **Purpose**: `isFlipped = true` document view so the playlist list lays out top-down. Used as `playlistScroll.documentView` container.

## CLASS ENTRY — `private class SettingsFlippedClipView: NSClipView` (line 2773)
- **Purpose**: `isFlipped = true` clip view so scrolling matches the flipped doc coordinates.

## CLASS ENTRY — `private class DownloadRowView: NSView` (line 2778)
- **Purpose**: row UI for the Downloads tab.
- **Props**: `let track: LocalTrack`; `weak var delegate: DynamicIslandPlayerView?`; `let playBtn/titleLbl/artistLbl/checkmarkImg`.
- **Init**: `init(track:tone:delegate:)`; `setupUI(tone:)` (height 40): play button → `handlePlayDownloadedTrack(_:)`; title + artist ("Offline Audio" when empty); green `checkmark.circle.fill` badge.
- **`menu(for:)`** → `delegate.contextMenu(for: track)`.
- **Consumers**: `makeDownloadRow`.

## CLASS ENTRY — `class LibraryNavButton: NSControl` (line 2881)
- **Purpose**: tab button for the library navigator (icon + title).
- **Props**: `let libraryTab: LibraryTab`; `var isSelected: Bool { didSet updateAppearance }`; `private var isHovered`; iconView/titleLabel/stackView; `trackingArea`; cached tone/isGlass/cyan.
- **Init**: `init(tab:)` → `setupUI()` (cornerRadius 6, icon 12×12 `libraryTab.symbol`, title 10pt, stack spacing 3.5).
- **Methods**: `updateTrackingAreas()` (mouseEnteredAndExited/activeInActiveApp), `mouseEntered`/`mouseExited` (hover), `mouseDown` (sends action → `handleLibraryNavTapped(_:)`), `refresh(tone:isGlass:cyan:)` (caches + redraw), `updateAppearance()` (selected = cyan bg `0.12/0.16` + border `0.35`; hovered = translucent bg; default = clear).
- **Consumers**: `libraryNavButtons` array; wired to `#selector(handleLibraryNavTapped(_:))` at line 111.

## Free function `rowPlayIconColor(tone:)` (line 3015)
- glass → `(0, 0.50, 0.90)`; dark tone → `white 1.0`; light → `(0, 0.85, 1.0)`.

## CLASS ENTRY — `private class DetailItemRowView: NSView` (line 3022)
- **Purpose**: playlist-detail track row with play + download state button and **drag-to-reorder**.
- **Props**: `let item: PlaylistItemRecord`; `weak var delegate`; `private var isDragging = false`; `playBtn`, `titleLbl`, `metaLbl`, `downloadBtn = CircularProgressDownloadButton()`.
- **Init**: `init(item:tone:delegate:)`; `setupUI(tone:)` (height 40): play → `handlePlayItemFromDetail(_:)`; meta shows artist or "Unknown Artist"; download button state resolved via `PlaylistManager.shared.resolve(item)` (`.local` → completed; `.online` → poll `DownloadManager.shared.statusFor(id:item.id, videoId:)` for queued/downloading/completed/failed); `.unavailable` → `.unavailable`; action `handleDownloadButtonTapped(_:)`; adds `VerticalPanGestureRecognizer` → `handlePanGesture(_:)`.
- **`setupObservers()`** (line 3048): observes `DownloadManager.progressNotification`; matches by `noteID == item.id` OR `noteVid == myVid`; updates download state + meta text ("Downloading N% • ETA …", "Queued in download list...", back to artist on completed/failed).
- **`deinit`**: removes all NotificationCenter observers (the only class here that does).
- **`menu(for:)`** → `delegate.contextMenu(for: item)`.
- **`handlePanGesture(_:)`** (line 3194): on began → drag shadow (zPosition 100, shadow 0.4/-2/6); on changed → find enclosing `NSStackView`, reorder `arrangedSubviews` when finger crosses another row's frame (animated 0.2s); on ended/cancelled → collect ordered `SwipeToDeleteContainerView.identifier.rawValue` IDs → `PlaylistManager.shared.reorderItems(playlistID:orderedItemIDs:)`.

## CLASS ENTRY — `private class VerticalPanGestureRecognizer: NSPanGestureRecognizer` (line 3254)
- **Purpose**: direction-locked vertical pan so horizontal swipe-to-delete (in the container) wins over reorder.
- **Logic**: on `mouseDown` reset lock; on `mouseDragged`: if `abs(dx) >= 3.0 && abs(dx) > abs(dy)*0.7` → lock horizontal → `state = .failed`; else if `abs(dy) >= 6.0 && abs(dy) > abs(dx)*0.7` → lock vertical; else ignore. Horizontal-locked drags return early.

## CLASS ENTRY — `private class HistoryRowView: NSView` (line 3292)
- **Purpose**: history-tab row.
- **Props**: `record`, `weak delegate`, `playBtn`, `titleLbl`, `metaLbl`, `downloadBtn`.
- **Init**: `setupUI(tone:)` (height 40): meta = "`<artist or Offline Audio/YouTube Music>` • `<relativePlayedTimeString>`"; play → `handlePlayHistoryRecord(_:)`; download state: local source → completed; else checks `allTracks` match (vid / title+artist) or `statusFor(id:record.id, videoId:)`; action `handleDownloadHistoryButtonTapped(_:)`.
- **`setupObservers()`** (line 3317): mirrors DetailItemRowView (matches `noteID == record.id` or `noteVid == record.ytVideoId`) — updates state + `animatePop()` on completion; does NOT rewrite meta label. `deinit` removes observers.
- **`menu(for:)`** → `delegate.contextMenu(for: record)`.

## CLASS ENTRY — `private class LikedSongRowView: NSView` (line 3460)
- **Purpose**: liked-songs tab row.
- **Props**: `record`, `weak delegate`, `playBtn`, `titleLbl`, `metaLbl`.
- **Init**: `setupUI(tone:)` (height 40): meta = "`<artist or YouTube Music>` • ♥ Saved"; play → `handlePlayLikedSong(_:)`. No download button. `menu(for:)` → `delegate.contextMenu(for: record)`.

---

# FILE 3 — `Views/Player/DynamicIslandPlayerView/ArtworkTheme.swift` (227 lines)

## FILE ENTRY

- **File path**: `Sources/Mooziac/Views/Player/DynamicIslandPlayerView/ArtworkTheme.swift`
- **Purpose**: `extension DynamicIslandPlayerView` — artwork loading (network + cache), fade transitions, ambient color extraction, and the full player theming engine (`applyTheme`).
- **Subsystem**: Views → Player → DynamicIslandPlayerView (theming subsystem).
- **Dependencies**: `PlayerDesign` (`.current`, notification `"YTM_playerDesignChanged"`), `NSCache` static, `CGImageSource` (ImageIO), NotificationCenter. **Communicates with**: Core.swift (props), SettingsPanel (refresh + highlight), any other view reading the static ambient colors / `"YTM_ambientThemeChanged"`.
- **Imports**: `AppKit`, `QuartzCore`, `ImageIO`.

## FUNCTION ENTRIES

### `loadArtwork(urlStr: String)` — line 6
- **Purpose**: fetch artwork thumbnail and update `artworkImageView`, honoring `artworkCache`.
- **Inputs**: `urlStr` (artwork URL).
- **Flow**: URL guard → cache hit: `applyArtworkAnimation { image = cached }`, return. Else `URLRequest(url:cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)`; `URLSession.shared.dataTask`: decode via `CGImageSourceCreateWithData`, thumbnail at index 0 with `kCGImageSourceCreateThumbnailFromImageAlways`, `kCGImageSourceCreateThumbnailWithTransform`, **`kCGImageSourceThumbnailMaxPixelSize: 128`**; build `NSImage(cgImage:size:44×44)`; on `.main`: cache object, `applyArtworkAnimation`, `updateAmbientGlow(cgImage:)`.
- **Async**: URLSession dataTask (background) → DispatchQueue.main. **Errors**: silently ignored (guard-returns). **Side effects**: network fetch, cache write, ambient theme update.

### `applyArtworkAnimation(_ updates: @escaping () -> Void)` — line 36
- Adds `CATransition` (duration 0.35, `.easeInEaseOut`, type `.fade`, key "artworkFade") then runs `updates()` (sets image).

### `ambientDominantColor(from cgImage: CGImage) -> NSColor` — line 45
- **Approach**: NOT dominant-color; it is an **average of saturated samples** `[V]`.
- Guard width/height > 0 → `NSColor.systemBlue`; guard dataProvider bytes → fallback `(0.20, 0.60, 1.0)`.
- `bytesPerPixel = bitsPerPixel / 8`; samples every `stepX = max(1, width/12)`, `stepY = max(1, height/12)` (up to 12×12=144 samples); reads raw RGBA bytes; includes a pixel only if `sat > 0.15 && maxC > 0.15` (filters dark/grey pixels); averages accepted R,G,B; if none accepted → fallback `(0.20, 0.60, 1.0)`.

### `updateAmbientGlow(cgImage:)` — line 96
- Computes `dominantColor`; converts to sRGB; derives:
  - **darkBg** = `0.22 × component`, alpha 0.96 (dark ambient pill bg).
  - **borderGlow** = `0.85 × component`, alpha 0.40.
- Stores `lastAmbientBgColor/lastAmbientBorderColor/lastAmbientAccentColor` + static `sharedAmbientBgColor/sharedAmbientAccentColor`; posts `"YTM_ambientThemeChanged"`.
- Then, **only if `PlayerDesign.current` is `.adaptive` or `.native`**: animates (0.5s) `containerPill.layer.backgroundColor = darkBg`, border width 1.0, borderColor = borderGlow, `waveformProgressView.accentColor = dominantColor`.

### `@objc applyTheme()` — line 128
- **Purpose**: re-theme entire player UI to `PlayerDesign.current`. Registered to `"YTM_playerDesignChanged"` (set by `PlayerDesign.current` setter).
- Animate 0.35s; three branches:
  - **`.adaptive`/`.native`**: pill bg = `lastAmbientBgColor ?? (0.08,0.08,0.10,0.98)`; border white 0.15; waveform accent = `lastAmbientAccentColor ?? (0.40,0.72,1.0)`; fonts title 13 bold / artist 11 medium / time 10 regular; colors: title white, artist white 0.65, time white 0.60; button tints white 0.80 (play white); like red if liked.
  - **`.darkMode`**: pill `(0.04,0.04,0.05,0.98)`; border white 0.12; waveform accent white; artist white 0.60, time white 0.55; button tints white 0.85; like red if liked.
  - **`.glassMode`**: pill bg `(0.93725, 0.94902, 0.94118, 0.98)` (comment: "Premium Light Mode #EFF2F0"); border `(0.80,0.82,0.81,0.85)`; fonts title 13 **heavy** / artist 11 **bold** / time 10 **semibold**; pitch black accents; like red if liked.
- Then: `downloadButton.updateVisuals()`, `updateDownloadButtonState()`, `refreshPlaylistsSection()`, `updateSettingsThemeHighlight()`, `updateBrowserButtonColor()`, `updateAddToPlaylistButtonColor()`, `updateRepeatButtonColor()`.

---

# FILE 4 — `Views/Windows/CenteredMenuBarLyricsWindowController.swift` (282 lines)

## FILE ENTRY

- **File path**: `Sources/Mooziac/Views/Windows/CenteredMenuBarLyricsWindowController.swift`
- **Purpose**: Singleton `NSWindowController` owning a borderless HUD window that shows synced lyrics (or title•artist) centered in the menu bar, plus transient volume/status overlay toasts. Also the shared overlay provider used by the player for text feedback ("Theme: …", "Repeat: …").
- **Subsystem**: Views → Windows.
- **Dependencies**: `NowPlayingManager` (observer + `currentState`), `LyricsManager.shared.fetchLyrics`, `SyncedLyricsParser.activeLineAndWord`, `LRCLine`, `PlaybackState`.
- **Imports**: `AppKit`, `QuartzCore`.

## CLASS ENTRY — `public class CenteredMenuBarLyricsWindowController: NSWindowController`

- **Purpose/Responsibilities**: HUD positioning in menu-bar center (or under notch), lyrics auto-scroll via 100ms timer, LRC line tracking per track, volume/status overlay with auto-dismiss.
- **Init**: builds `NSWindow(contentRect: 280×22, styleMask: [.borderless], .buffered, defer: false)`; `backgroundColor = .clear`; `isOpaque = false`; `hasShadow = false`; `level = .statusBar`; `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`; `isMovableByWindowBackground = false`; then `setupUI()`, `setupObservers()`, `repositionInCenter(contentWidth: 280)`. `required init?(coder:)` → `fatalError`.
- **Properties**: `private let containerView = NSView()`; `private let lyricsLabel = NSTextField(labelWithString: "")`; `private var displayTimer: Timer?`; `private var volumeOverlayTimer: Timer?`; `private var isShowingVolumeOverlay = false`; `private var currentLRCLines: [LRCLine] = []`; `private var currentTrackKey = ""`; `private var lastState = PlaybackState()`.
- **Public API**: `static let shared`; computed `var isEnabled` (UserDefaults `"YTM_v3_isCenteredLyricsEnabled"`, default false; setter also shows/hides window); `showVolumeOverlay(volumePercent:isAppOnly:)`; `showCustomTextOverlay(text:duration:)`; `repositionInCenter(contentWidth:)`; `showOverlay()`; `toggleOverlay()`.
- **Consumers**: `DynamicIslandPlayerView` (repeat/theme/progress toasts + keyDown overlay), app volume engine (`showVolumeOverlay` `[I]`), settings drawer lyric toggle (`isEnabled`), `KeyboardCommandHandler` overlay `[I]`.
- **Lifecycle**: singleton, never deallocated; `deinit` invalidates both timers. Observers: `NowPlayingManager.shared.addObserver` closure + `NSApplication.didChangeScreenParametersNotification`.
- **State**: `isEnabled`, `lastState`, `currentTrackKey`, `currentLRCLines`, `isShowingVolumeOverlay`, timers.
- **What would break if removed**: all lyrics HUD, all overlay toasts (volume, theme, repeat, keyboard feedback); many callers would lose user feedback.

## FUNCTION ENTRIES

### `var isEnabled` — line 18
- Getter: `UserDefaults.standard.object(forKey: "YTM_v3_isCenteredLyricsEnabled") as? Bool ?? false`. Setter: persist; if `true` → `showOverlay()`; else `window?.orderOut(nil)`.

### `init()` — line 30
- As above. **Side effects**: window setup + observers + initial positioning.

### `deinit` — line 55
- Invalidates `displayTimer` + `volumeOverlayTimer`.

### `setupUI()` — line 60 (private)
- Content view 280×22; `containerView` pinned to content; `lyricsLabel` (11.5pt semibold, white 0.95, centered, single-line, truncating tail) pinned edges.

### `setupObservers()` — line 94 (private)
- `NowPlayingManager.shared.addObserver { state in DispatchQueue.main.async { self?.handleStateUpdate(state) } }`.
- `NotificationCenter` observer for `NSApplication.didChangeScreenParametersNotification` → `handleDisplayChange`.

### `@objc private handleDisplayChange()` — line 109
- `repositionInCenter(contentWidth: window?.frame.width ?? 280)` (handles monitor reconfig).

### `handleStateUpdate(_ state: PlaybackState)` — line 113 (private)
- Stores `lastState`. If `isEnabled && state.isPlaying` → ensure `startLoop()`; else invalidate timer + order-out window (if not showing volume overlay).
- Track-key change (`trackID.isEmpty ? "title|artist" : "VID:"+trackID`): reset `currentLRCLines`; async `LyricsManager.shared.fetchLyrics(artist:title:duration:trackID:)` completion checks `requestKey == currentTrackKey` before applying (stale-response guard).
- **Async**: fetchLyrics completion; **race-guarded** via requestKey.

### `startLoop()` — line 144 (private)
- Invalidates prior; `Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true)` → `updateLyricsFrame()`; added to `.common` runloop mode (survives menu tracking).

### `updateLyricsFrame()` — line 152 (private)
- Guard `isEnabled && !isShowingVolumeOverlay`. Guard playing + title present else order-out.
- `showOverlay()` (keeps window on top); `accurateTime = state.getAccurateTime()`; pick text: active LRC line via `SyncedLyricsParser.activeLineAndWord(at:in:leadOffset: 0.35)` → `.line.text`; else "`<shortTitle>` • `<shortArtist>`" (both truncated at 30 chars + "…").
- If text changed: `CATransition` fade 0.06s key "subtleFadeLyrics"; compute target width `min(max(ceil(textWidth/30)*30 + 30, 160), 260)`; `repositionInCenter(contentWidth: targetWidth)`.

### `showVolumeOverlay(volumePercent:isAppOnly:)` — line 194 (public)
- Prefix "App Sound: " vs "Volume: "; 0% → "App Muted"/"Muted"; else "`<prefix><N>%`"; delegates to `showCustomTextOverlay`.

### `showCustomTextOverlay(text:duration:1.5)` — line 200 (public)
- Invalidates volume timer; `isShowingVolumeOverlay = true`; `showOverlay()`; set label; width formula `min(max(ceil(textWidth/30)*30+30, 180), 300)`; `repositionInCenter`; schedule dismiss `Timer(timeInterval: duration, repeats: false)` in `.common` mode → `completeOverlayDismissal()`.

### `completeOverlayDismissal()` — line 219 (private)
- Invalidate/nil volume timer; `isShowingVolumeOverlay = false`; if `!(isEnabled && lastState.isPlaying)` and window visible → `orderOut`.

### `repositionInCenter(contentWidth:)` — line 229 (public)
- **Positioning math** `[V]`: `menuBarHeight = max(24, screenRect.maxY - visibleRect.maxY)`; `hasNotch` = macOS 12+ `safeAreaInsets.top > 0 || auxiliaryTopLeftArea != nil`.
  - **Notch path**: y = `screenRect.maxY − menuBarHeight − 22 − 3`; capsule styling: `containerView.layer.backgroundColor = black 0.72`, cornerRadius 11, masksToBounds true ("Dynamic Island capsule HUD").
  - **No-notch path**: y = `screenRect.maxY − menuBarHeight + ((menuBarHeight − 22)/2)`; container clear, radius 0 ("Standard center alignment directly within the menu bar").
  - x = `midX − contentWidth/2`.
- Animates frame change 0.25s easeInEaseOut via `window?.animator().setFrame(...)`.

### `showOverlay()` — line 273 (public)
- `window?.orderFront(nil)` if not visible.

### `toggleOverlay()` — line 279 (public)
- `isEnabled.toggle()`.

---

# FILE 5 — `Views/Windows/LaunchAnimationController.swift` (173 lines)

## FILE ENTRY

- **File path**: `Sources/Mooziac/Views/Windows/LaunchAnimationController.swift`
- **Purpose**: Runs the app-launch "Dynamic Island fly-in" animation: a full-screen SwiftUI overlay panel that fades in a logo, breathes, flies/shrinks toward the exact status-bar icon position, bursts a sparkle, then dismisses.
- **Subsystem**: Views → Windows (launch).
- **Dependencies**: `LaunchAnimationTimeline` (Models), `ClickSound` (Audio), `LaunchOverlayModel`/`LaunchOverlayView` (same folder), `StatusItemManager.shared` (`.statusButtonCenterInScreen`, `.playLaunchPopAnimation()`).
- **Imports**: `AppKit`, `SwiftUI`. `@MainActor` class.
- **Classes defined**: `final class LaunchAnimationController` (internal, @MainActor).
- **Notable**: `LaunchAnimationTimeline` (a 10-field timing struct: `fadeIn 0.45`, `pulseCount 2`, `firstPulse 0.35`, `pulseInterval 0.55`, `pulseRise 0.25`, `pulseFall 0.35`, `hold 0.22`, `fadeOut 0.55`, `pulseTime/pulseTimes/fadeOutStart/total` helpers) is instantiated but **its fields are never read in this controller** — `run` uses hardcoded durations `[V][I dead model]`.

## CLASS ENTRY — `final class LaunchAnimationController`

- **Purpose**: orchestrates the launch overlay lifecycle.
- **Properties**: `public static let shared`; `private let timeline = LaunchAnimationTimeline()` `[I unused]`; `private let sound = ClickSound()`; `private var panel: NSPanel?`; `private var model: LaunchOverlayModel?`; `private var task: Task<Void, Never>?`; `var isPlaying: Bool { task != nil }`.
- **Public API**: `play(completion: () -> Void = {})`, `cancel()`. Rest is private.
- **Consumers**: app startup (AppDelegate `[I]`).
- **Lifecycle**: `play` guard `!isPlaying`; builds model/panel; `panel.orderFrontRegardless()`; starts `Task` running `run` then `finish()` then `completion()`. `cancel` cancels task + `finish()`.
- **State**: panel/model/task; `isPlaying` derived.
- **What would break if removed**: launch flourish (cosmetic); `StatusItemManager.playLaunchPopAnimation` still exists independently.

## FUNCTION ENTRIES

### `play(completion:)` — line 17
- Guards `!isPlaying` and `NSScreen.main` (else completion()); creates `LaunchOverlayModel()`; initial target from `StatusItemManager.shared?.statusButtonCenterInScreen` → `targetOffsetX = center.x − screen.width/2`, `targetOffsetY = −(center.y − screen.height/2)`; fallback `x = width*0.35`, `y = −(height/2 − 18)`; `makePanel(on:model:)`; stores; `orderFrontRegardless()`; Task → `await run(timeline, model:, screen:)`, `finish()`, `completion()`.
- **Async**: Task-based, `@MainActor`.

### `cancel()` — line 51
- `task?.cancel()`; `task = nil`; `finish()`.

### `computeStatusItemTarget(on screen:) -> (x, y)` — line 57 (private)
- Prefers `statusButtonCenterInScreen` if `x>0 && y>0` (same formula as play).
- Fallback: scans `NSApplication.shared.windows` for class name containing "Status"/"StatusBar", `frame.minY >= screen.height−60 && frame.midX > 0` → center math. (Note: actual status bar window class is `NSStatusBarWindow` — string check is loose `[I]`.)
- Final fallback `(width*0.38, −(height/2 − 14))`.

### `run(_ timeline:model:screen:) async` — line 81 (private)
Hardcoded phase timeline `[V]`:
1. **0.00–0.30s** fade in: `opacity=1`, `logoOpacity=1`, `logoScale=1`, `edgeGlowOpacity=0.45` (easeOut 0.30).
2. sleep 0.30 → **0.30–0.52s** breath pulse `logoScale=1.08` (easeInOut 0.22); sleep 0.22.
3. Recompute target via `computeStatusItemTarget` (comment: "guaranteed laid out after 0.52s!"), update model.
4. **0.52s** `sound.play()` (AudioServices 1104 — **this is a system sound, not haptics** `[V]`); spring `(response 0.65, dampingFraction 0.82)`: `logoOffsetX/Y = target`, `logoScale = 0.075`, `edgeGlowOpacity = 0`; sleep 0.52.
5. **1.04s** `StatusItemManager.shared?.playLaunchPopAnimation()`; easeOut 0.28: `sparkleScale=2.4`, `sparkleOpacity=0.95`, `logoOpacity=0`; then easeOut 0.25 delayed 0.12: `sparkleOpacity=0`, `opacity=0`; `_ = await sleep(0.35)` (result discarded).
- **Async**: all sleeps cancellable via `sleep()`; cancellation propagates through `guard await sleep(...)` returns.

### `sleep(_:) async -> Bool` — line 131 (private)
- `duration <= 0` → `!Task.isCancelled`; else `Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))`, `catch` → false.

### `finish()` — line 141 (private)
- `sound.stop()` (no-op); `panel?.orderOut(nil)`; `panel?.close()`; nil panel/model/task.

### `makePanel(on:model:) -> NSPanel` — line 150 (private)
- `NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], ...)`; `contentView = NSHostingView(rootView: LaunchOverlayView(model: model))`; `isOpaque=false`, clear bg, `hasShadow=false`, `ignoresMouseEvents=true`, **`level = .screenSaver`**, `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`; `isReleasedWhenClosed = false`; `hidesOnDeactivate = false`; `animationBehavior = .none`; `setFrame(screen.frame, display: false)`.

---

# FILE 6 — `Views/Windows/LaunchOverlayView.swift` (152 lines)

## FILE ENTRY

- **File path**: `Sources/Mooziac/Views/Windows/LaunchOverlayView.swift`
- **Purpose**: SwiftUI overlay content for the launch animation — observable animation model + the visual composition.
- **Subsystem**: Views → Windows (launch).
- **Imports**: `SwiftUI`.

## CLASS ENTRY — `@MainActor final class LaunchOverlayModel: ObservableObject`

- **Purpose**: animation state bindings consumed by both controller and view.
- **Properties** (`@Published`, all `Double`): `opacity = 0`; `logoScale = 0.95`; `logoOpacity = 0`; `logoOffsetY = 0`; `logoOffsetX = 0`; `targetOffsetX = 0`; `targetOffsetY = -480`; `sparkleScale = 0.2`; `sparkleOpacity = 0`; `edgeGlowOpacity = 0.45`.
- **Consumers**: `LaunchAnimationController` (writes), `LaunchOverlayView` (reads).

## CLASS ENTRY — `struct LaunchOverlayView: View`

- **Purpose**: renders the launch composition.
- **Static constants**: colors `mildRed (0.95,0.25,0.32)`, `mildCoralRed (0.98,0.38,0.35)`, `softCrimson (0.88,0.20,0.28)`, `warmRose (1.00,0.42,0.40)`; `sideDepth = 0.018`, `topDepth = 0.020`.
- **`appIconImage: NSImage`** (line 31): `Bundle.main.image(forResource: "launch_transparent") ?? Bundle.main.image(forResource: "MOOZIAC") ?? Bundle.main.image(forResource: "MOOZIAC_transparent")`; fallback SF Symbol `music.note.house.fill`; ultimate fallback empty `NSImage`.
- **`body`** (line 38): full-screen GeometryReader/ZStack:
  1. If `edgeGlowOpacity > 0.01`: `RadialGradient` splash (stops at 0.0/0.50/0.85, opacity scaled `0.05`/`0.03`, startRadius 50, endRadius `min(w,h)*0.50`) + 4 `siriEdgeRibbon` strips.
  2. Sparkle burst `Circle` (34×34, `LinearGradient` stroke width 3.5, blur 1.2, `scaleEffect sparkleScale`, `offset targetOffsetX/Y`).
  3. Hero icon 380×380, `scaleEffect logoScale`, `offset logoOffsetX/Y`, `shadow mildRed 0.35×logoOpacity radius 16×max(0.1, logoScale)`.
  - Whole view `.opacity(model.opacity)`, `.ignoresSafeArea()`, `.allowsHitTesting(false)`.
- **`siriEdgeRibbon(_ edge:in:)`** (line 96): gradient ribbon frame depth `sideDepth` (side) / `topDepth` (top/bottom) × screen dim, gradient stops `[1.0, 0.70, 0.30, 0.0]` opacity of `edgeGlowOpacity`, blur 25, aligned to edge.
- **Helpers** `startPoint/endPoint/alignment(for:)` (lines 126/135/144): map Edge → UnitPoint/Alignment (top↔bottom, leading↔trailing).

---

# FILE 7 — `Views/Windows/NativeGestureTutorialWindowController.swift` (85 lines)

## FILE ENTRY

- **File path**: `Sources/Mooziac/Views/Windows/NativeGestureTutorialWindowController.swift`
- **Purpose**: Shows a pitch-black rounded WKWebView panel displaying `trackpad.html` (which renders the `macbook_panel.jpg` trackpad diagram and gesture hotspots) so users can learn native trackpad gestures. Sticks itself where the main player pill is.
- **Subsystem**: Views → Windows (tutorial).
- **Dependencies**: `StatusItemManager.shared.positionCustomWindow(_:width:height:)`; `trackpad.html` resource (which itself loads `macbook_panel.jpg` — coupled pair per AGENTS.md `[I]`).
- **Imports**: `AppKit`, `WebKit`.

## CLASS ENTRY — `final class NativeGestureTutorialWindowController: NSWindowController`

- **Purpose/Responsibilities**: build the tutorial panel, load HTML, position under the status item, close.
- **Properties**: `static let shared`; `private var webView: WKWebView!`.
- **Init**: `convenience init()` — `NSPanel(contentRect: 360×250, styleMask: [.borderless, .nonactivatingPanel], .buffered, defer: false)`; `isOpaque=false`; clear bg; `hasShadow=true`; `level = .statusBar`; `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]`; `isMovableByWindowBackground = true`; `hidesOnDeactivate = false`; then `setupUI(window:)`.
- **Public API**: `showTutorial()`, `@objc closeTutorial()`.
- **Consumers**: status-item menu action `[I]`.

## FUNCTION ENTRIES

### `convenience init()` — line 9
- As above. Note: `self.init(window: panel)` via convenience initializer pattern.

### `setupUI(window:)` — line 28 (private)
- `blackView` 360×250: black bg, `cornerRadius = 16`, `masksToBounds = true`, border `white 0.2, alpha 0.8`, width 1.0.
- **Close button** `"✕"` (12pt bold, tint white 0.85) at frame `(330, 220, 22, 22)`, `layer?.zPosition = 999`, action `closeTutorial`.
- `WKWebViewConfiguration`; `webView` 360×250; `setValue(false, forKey: "drawsBackground")` (transparent WebKit); `wantsLayer = true`; layer bg black; added `.below` close button.
- `loadHtml()`.

### `loadHtml()` — line 62 (private)
- `Bundle.main.path(forResource: "trackpad", ofType: "html")` guard; `webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())` — grants read access to the whole folder so `macbook_panel.jpg` loads.
- **Errors**: silently returns if resource missing `[I]`.

### `showTutorial()` — line 68
- Re-loads HTML each time (fresh state); if `StatusItemManager.shared` exists → `manager.positionCustomWindow(window, width: 360, height: 250)` (pins at status-bar icon position, same as main player); else `window.center()`; `window.makeKeyAndOrderFront(nil)`.
- **Note**: `makeKeyAndOrderFront` on a nonactivating panel — panel does not steal focus `[I]`.

### `@objc closeTutorial()` — line 82
- `window?.orderOut(nil)`.

---

# UI REVERSE-ENGINEERING MATRICES

## Component → State → Action → Handler → Backend → Update → Visual result

### Compact player (Core.swift)

| Component | Reflects | User action | Handler | Backend | State update | Visual result |
|---|---|---|---|---|---|---|
| playPauseButton | `state.isPlaying` | click | `playPauseTapped` | `delegate.dynamicIslandDidTapPlayPause` → NowPlayingManager | optimistic `lastPlayPauseIcon` | icon flips play↔pause |
| nextButton / previousButton | — | click | `nextTapped`/`previousTapped` | delegate → NowPlayingManager | — | bounce animation |
| likeButton | `state.isLiked` | click | `likeTapped` | `NowPlayingManager.shared.toggleLike()` | `isLiked` | heart↔heart.fill + red tint + heart-pop |
| repeatButton | `repeatMode` | click | `repeatTapped` | `NowPlayingManager.shared.setRepeatMode` | `repeatMode` | `repeat`↔`repeat.1` icon, cyan when active, overlay toast |
| searchIconButton + searchField | expanded state | click/type/Enter | `searchIconTapped`/`searchSubmitted` | `delegate.dynamicIslandDidSearch` (after URL/offline guards) | `isCollapsingSearch` | slide-out field 0.30s, controls shift to leading |
| waveformProgressView | `state.duration`, progress | drag/scrub | `onSeek` closure | `delegate.dynamicIslandDidSeek(to: ratio*duration)` | scrubbing flag in view | waveform fills |
| downloadButton | download task state | click | `downloadCurrentTrackTapped` | `DownloadManager.queueTrack/cancelTask` + LocalLibrary check | `downloadButton.downloadState` | idle→queued→spinner→checkmark; toasts |
| browserButton | `activeSettingsMode` | click | `browserTapped` | — | `isSettingsExpanded` | drawer expands, cyan highlight |
| addToPlaylistButton | `activeSettingsMode` | click | `addToPlaylistButtonTapped` | — | drawer mode = playlist | playlist subview appears |
| fullScreenButton | — | click | `fullScreenTapped` | `delegate.dynamicIslandDidTapWebBrowser` | collapse settings | full YTM web view |
| resetPositionButton | drag-from-dock state | click | `resetPositionTapped` | `delegate.dynamicIslandDidTapResetPosition` | — | player snaps back to menu bar |
| toastView | transient feedback | — | `showToastBanner` | varies | — | 2.8s banner, warning/success border |
| view | settings drawer | double-click / outside click | `mouseDown` / `PillContainerView.onBackgroundClick` | — | `isSettingsExpanded` | drawer toggles |
| view | keyboard state | key | `keyDown` | `KeyboardCommandHandler.handle` + overlay closure | — | media keys act + overlay feedback |

### Settings drawer (SettingsPanel.swift)

| Component | Reflects | Action | Handler | Backend | Result |
|---|---|---|---|---|---|
| Theme row | `PlayerDesign.current` | cycle tap | `themeCycleTapped` | `PlayerDesign.current = …` (posts YTM_playerDesignChanged) | re-theme + overlay toast |
| Progress row | `ProgressStyle.current` | cycle tap | `progressStyleCycleTapped` | `ProgressStyle.current = …` (posts ProgressStyleDidChange) | waveform re-render + toast |
| App-Only Sound toggle | `AppVolumeManager.isAppVolumeOnly` | tap | `NativeCapsuleToggleView.onToggle` | `AppVolumeManager.shared.isAppVolumeOnly = $0` | persisted via manager |
| Master Gestures toggle | `EdgeVolumeEngine.isEnabled` | tap | onToggle | `EdgeVolumeEngine.shared.isEnabled = $0` | gestures enable/disable |
| Lyrics toggle | `isEnabled` | tap | onToggle | `CenteredMenuBarLyricsWindowController.shared.isEnabled = $0` | lyrics HUD shows/hides (UserDefaults key) |
| Discord toggle | `DiscordRPCManager.isEnabled` | tap | onToggle | `DiscordRPCManager.shared.isEnabled = $0` | presence on/off |
| Library nav buttons | `activeLibraryTab` | click | `handleLibraryNavTapped` | tab switch | list re-render + chrome |
| Playlist row | playlist list | click / right-click / swipe | `onRowClicked`/contextMenu/`onDelete`/`onRightSwipePlay` | `PlaylistManager` start/delete | detail push / delete / play toast |
| Detail row | playlist items | play / download / drag / right-click | `handlePlayItemFromDetail`/`handleDownloadButtonTapped`/`handlePanGesture`/contextMenu | `PlaylistManager.startPlaylist`, `DownloadManager`, `reorderItems` | playback, download ring, reorder persist |
| Downloads tab | `LocalLibraryManager.allTracks` | import/play-all/shuffle | `handleDownloadsImportTapped` etc. | `importFiles`, `playOfflineTrack` | toasts + list refresh |
| History tab | `HistoryManager` | play/download | `handlePlayHistoryRecord`/`handleDownloadHistoryButtonTapped` | `playHistoryItem`, `queueTrack` | playback + toast |
| Liked tab | `LikedSongsManager` | play/remove | `handlePlayLikedSong`/`removeLikedSong` | `playOfflineTrack`/`playOnlineVideo`, DB remove | playback + toast + refresh |
| Search toggle + field | `isPlaylistSearchActive` | click/type | `handlePlaylistSearchToggle`/`handlePlaylistSearchChanged` | live filter over manager fetches | width anim 165, filtered rows |
| Create (＋) | `isPlaylistCreateOpen` | click/Enter/cancel | `handleCreateNewPlaylistFromHeader`/`handleInlineCreateConfirm`/`handleInlineCreateCancel` | `createPlaylist` | inline field anim 175, toast, refresh |
| Selection/Done/BulkDelete | `isPlaylistSelectionMode`/`selectedPlaylistIDs` | click | `handleTogglePlaylistSelectionMode`/`handlePlaylistContextSelect`/`handleBulkDeletePlaylists` | `deletePlaylist` | checkboxes, alert, toast |
| Download All (detail) | download plan | click | `handleDownloadAllFromDetailHeader` | `planDownloads` + `queueTracks` | toast + tooltip progress |

### Artwork theming

| Component | Reflects | Trigger | Handler | Backend | Result |
|---|---|---|---|---|---|
| artworkImageView | `state.artworkUrl` / offline track art | `updateState` | `loadArtwork` | URLSession + ImageIO thumbnail (≤128px) | cached fade-in image |
| containerPill bg/border | artwork dominant avg color | artwork loaded | `updateAmbientGlow` | raw bitmap sampling | pill tinted dark-bg + border glow (adaptive/native only) |
| All UI colors | `PlayerDesign.current` | setter posts `YTM_playerDesignChanged` | `applyTheme` | reads last ambient colors | re-themed controls/fonts |

### Lyrics HUD

| Component | Reflects | Trigger | Handler | Backend | Result |
|---|---|---|---|---|---|
| lyricsLabel | synced LRC line / title•artist | 0.1s timer | `updateLyricsFrame` | `SyncedLyricsParser.activeLineAndWord(leadOffset:0.35)` | faded lyric swap, width recompute |
| window | menu-bar center/notch | enabled/playing | `repositionInCenter` | screen geometry | animated frame move (0.25s) |
| window | volume/status | `showVolumeOverlay`/`showCustomTextOverlay` | overlay timers | — | transient text, auto-dismiss 1.5s |

### Launch animation

| Component | Reflects | Trigger | Handler | Backend | Result |
|---|---|---|---|---|---|
| full-screen NSPanel | model published values | `LaunchAnimationController.play` | `run` phases | `StatusItemManager.statusButtonCenterInScreen` + `playLaunchPopAnimation` + `ClickSound.play` | fade→breath→fly/shrink to icon→sparkle burst→dismiss |

### Tutorial window

| Component | Reflects | Action | Handler | Backend | Result |
|---|---|---|---|---|---|
| WKWebView (black panel) | trackpad.html content | open | `showTutorial` | `positionCustomWindow` + `loadFileURL` | panel at player position showing gesture guide |
| Close ✕ | — | click | `closeTutorial` | — | panel hidden |

---

# CROSS-FILE COMMUNICATION SUMMARY

- **Core.swift → NowPlayingManager**: `updateState` input; `setRepeatMode`, `toggleLike`, `engineMode`, `currentState` reads.
- **Core.swift → DownloadManager**: `statusFor`, `queueTrack`, `cancelTask`, `extractVideoID`, progress/queue notifications.
- **Core.swift/SettingsPanel → PlaylistManager**: fetch/create/delete/append/start/shuffle/reorder/planDownloads/playOnlineVideo/playNext/addToQueue.
- **Core.swift/SettingsPanel → LikedSongsManager / HistoryManager / LocalLibraryManager / LocalDatabaseManager**: fetch + delete + play offline + toggleLike.
- **All → CenteredMenuBarLyricsWindowController.shared**: `showCustomTextOverlay`, `isEnabled`.
- **ArtworkTheme → rest of app**: static `sharedAmbientBgColor/sharedAmbientAccentColor` + notification `"YTM_ambientThemeChanged"`.
- **LaunchAnimationController → StatusItemManager**: `statusButtonCenterInScreen`, `playLaunchPopAnimation`.
- **NativeGestureTutorialWindowController → StatusItemManager**: `positionCustomWindow`.
- **PlayerDesign/ProgressStyle**: notifications `"YTM_playerDesignChanged"` / `"ProgressStyleDidChange"`; UserDefaults `YTM_playerDesign`, `YTM_progressStyle`, `YTM_v3_useWaveformProgress`.

---

# RISKS & OBSERVATIONS

**Dead code / unused members** `[I]`:
1. `DynamicIslandPlayerViewDelegate.dynamicIslandDidTapShuffle()` and `dynamicIslandDidTapRepeat()` — never called in these files.
2. `isRepeatActive` property (Core.swift:41) — never read/written.
3. `themeSlider` (Core.swift:83) — declared, unused in these files.
4. `themeSectionLabel` (Core.swift:85) — declared, never added to hierarchy or referenced.
5. `flashGlowOnButton()` (Core.swift:769) — no callers.
6. `handleClosePlaylistPanel` (SettingsPanel:524), `handleTogglePlaylistRow` (2223), `handleOpenFullPlaylistLibrary` (2231), `handleOpenPlaylistDetail` (2236), `handleAddToPlaylistRow` (2365) — no wire-up found in these files.
7. `LaunchAnimationTimeline` fields — model instantiated but the controller's `run` uses hardcoded timings; the 10-field model is unused data.
8. `ClickSound.stop()` is a no-op.

**Duplicated logic** `[V]`:
9. Download-state resolution duplicated 4×: `updateDownloadButtonState` (Core), `DetailItemRowView.setupUI`, `HistoryRowView.setupUI`, plus the "is already downloaded" scan in HistoryRowView vs Core — drift risk.
10. Download progress/queue notification handling appears in `setupUI` (Core) and again in `DetailItemRowView`/`HistoryRowView` observers; the Core one only updates a tooltip.
11. `makeFeatureRow` vs `makeThemeFeatureRow`/`makeProgressStyleFeatureRow` — large copy/paste for row construction.
12. Context-menu builders `contextMenu(for:)` ×4 are structurally near-identical.
13. The status-bar target computation logic in `LaunchAnimationController.play` is duplicated inside `computeStatusItemTarget` with slightly different fallbacks (`0.35`/`18` vs `0.38`/`14`).

**Missing error handling / silent failures** `[V]`:
14. `loadArtwork` swallows all network/decoding errors silently.
15. `handlePlayLikedSong` returns silently if a like can't be resolved.
16. Several `guard let` returns in drawer handlers produce no feedback to the user.
17. `nativeGestureTutorial.loadHtml` silently does nothing if `trackpad.html` is missing from the bundle.
18. `LaunchAnimationController.play` completes without animation if `NSScreen.main` is nil.

**Potential leaks / fragile state** `[I]`:
19. `DynamicIslandPlayerView.setupUI()` registers 5 block-based NotificationCenter observers that are **never removed** (no `deinit`); repeated init would duplicate them.
20. `CenteredMenuBarLyricsWindowController` is a singleton with `NSTextField` mutated every 0.1s — fine, but the `NowPlayingManager.addObserver` closure strongly captures self via `[weak self]` (OK) — timers are managed; `deinit` never runs (singleton) so timer teardown relies on code paths.
21. `DetailItemRowView`/`HistoryRowView` `deinit` remove observers, but `DownloadRowView`/`LikedSongRowView` have no observers (fine); the scroll doc view keeps `SwipeToDeleteContainerView` rows alive via stack; `refreshPlaylistsSection` rebuilds every time → rows/observers churn on every library update; combined with item #19 this is the main leak/perf concern.
22. `refreshPlaylistsSection()` + `resetPlaylistSectionChrome()` + `updateSettingsThemeHighlight()` are invoked together after almost every drawer action (N+ cascade); each rebuild clears and recreates every row view + constraints. On large libraries (hundreds of tracks) this is O(n) view creation per interaction — potential UI jank on the main thread.
23. `updateSettingsThemeHighlight()` sets `libraryNavContainer.layer?.borderWidth = 0`/`backgroundColor = clear` every call — harmless but redundant.
24. `DownloadRowView`/`HistoryRowView`/`LikedSongRowView`/`DetailItemRowView` store `track`/`record`/`item` strongly while holding `weak delegate` — row lifetime is owned by the stack, so no cycle, but stale rows keep model objects alive until the next `refreshPlaylistsSection`.
25. `handleDrawerToggleLikeDownloadItem` reads `track.isLiked` AFTER toggling via `LocalLibraryManager.shared.toggleLike(for:)` and shows "♥ Liked Track"/"Removed Like" based on the pre-toggle value — the toast message can be inverted relative to the actual new state `[I logic bug candidate]`.
26. `mouseDown` double-click expands preferences even when clicking on child controls (no hit-test guard before the double-click branch) — double-clicking e.g. the play button may also toggle the drawer `[I]`.
27. `controlTextDidChange` clears the search field whenever a link is detected mid-typing, deleting the user's entire query (not just the offending text) — aggressive UX.
28. `verticalPanGestureRecognizer` and `SwipeToDeleteContainerView` both handle horizontal drags; the failure-lock heuristic (3pt vs 6pt thresholds) is fragile — borderline diagonal drags may trigger neither gesture.
29. In `updateState`, all visual work is skipped when `window.isVisible == false` but track-diff caches (`lastTrackTitle/Artist`) are still updated — on window re-show the labels are re-synced only if the next state tick re-diffs them; if playback hasn't ticked since, the visible labels can be stale until the next update `[I]`.
30. `computeStatusItemTarget` string-matches window class names containing "Status"/"StatusBar" — fragile against AppKit's actual private class naming (`NSStatusBarWindow`), mitigated only by the primary `statusButtonCenterInScreen` path.
31. `LaunchAnimationController` `sound.play()` triggers system sound 1104 at 0.52s; no haptics used. If sound should be disabled, there is no toggle in this file — only `ClickSound`'s no-op `stop()`.

---

# SUMMARY COUNTS

| Metric | Count |
|---|---|
| Files documented | **7** (Core.swift 1176L, SettingsPanel.swift 3546L, ArtworkTheme.swift 227L, CenteredMenuBarLyricsWindowController.swift 282L, LaunchAnimationController.swift 173L, LaunchOverlayView.swift 152L, NativeGestureTutorialWindowController.swift 85L) |
| Classes/types documented | **16** — DynamicIslandPlayerViewDelegate (protocol), DynamicIslandPlayerView, PillContainerView, SettingsFlippedDocView, SettingsFlippedClipView, DownloadRowView, LibraryNavButton, DetailItemRowView, VerticalPanGestureRecognizer, HistoryRowView, LikedSongRowView, CenteredMenuBarLyricsWindowController, LaunchAnimationController, LaunchOverlayModel, LaunchOverlayView, NativeGestureTutorialWindowController (+ ClickSound/LaunchAnimationTimeline as referenced deps) |
| Functions/methods/selectors documented | **≈ 200** (Core ≈ 40; SettingsPanel ≈ 90 incl. ~40 `@objc` action selectors; ArtworkTheme 5; LyricsHUD ≈ 12; LaunchController 8; LaunchOverlayView 6; Tutorial 3; plus helper closures/timers/gestures) |
| UserDefaults keys directly used | **5** — `YTM_lastTitle`, `YTM_lastArtist`, `YTM_lastArtwork`, `YTM_lastIsLiked`, `YTM_v3_isCenteredLyricsEnabled` (indirect: `YTM_playerDesign`, `YTM_progressStyle`, `YTM_v3_useWaveformProgress`) |
| Notification names | **10** — `YTM_playerDesignChanged`, `NetworkMonitorStatusChanged`, `Mooziac_LibraryUpdated`, `HistoryManager.historyUpdatedNotification`, `LikedSongsManager.likedSongsUpdatedNotification`, `DownloadManager.progressNotification`, `DownloadManager.queueNotification`, `YTM_ambientThemeChanged`, `ProgressStyleDidChange`, `NSApplication.didChangeScreenParametersNotification` |
| Asset / resource names | **4** — `launch_transparent`, `MOOZIAC`, `MOOZIAC_transparent`, `trackpad.html` (+ coupled `macbook_panel.jpg` per AGENTS.md `[I]`) |
| Risks/observations found | **31** (8 dead-code, 5 duplication, 5 error-handling, 8 leak/fragile-state, 5 behavior/perf misc)