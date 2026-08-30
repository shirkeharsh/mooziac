# Mooziac — Blueprint: Library Views & Reusable Components

Technical archive for 11 source files under `Sources/Mooziac/Views/Libraries/` and `Sources/Mooziac/Views/Components/`.
All line numbers are approximate (verified against the current files). Anything not provable from source is explicitly tagged
`INFERRED FROM SOURCE` or `UNKNOWN — requires runtime verification`.

---

## FILE 1 — PlaylistLibraryView.swift

**Path:** `Sources/Mooziac/Views/Libraries/PlaylistLibraryView.swift` (3408 lines)

**Purpose:** The main library browser inside the player popover. A single `NSTableView` driven by an internal `Mode` enum (list of playlists / playlist detail / liked songs / downloads / history). Provides search, drag-and-drop import, drag reordering of playlist items, swipe-to-delete and swipe-to-play rows, right-click context menus per mode, header action buttons, bottom action bar, empty states, and theme-aware styling.

**Subsystem:** Library browser UI (Views/Libraries).

**Imports:** `AppKit`, `Foundation`, `UniformTypeIdentifiers`.

**Dependencies (external types referenced):**
- `PlaylistManager.shared` — fetchPlaylists, fetchPlaylistItems, summaryForPlaylist, startPlaylist, playOnlineVideo, createPlaylist, createPlaylistFromCurrentQueue, appendCurrentPlayingTrack, renamePlaylist, deletePlaylist, removeItem, reorderItems, appendPlaylistItem, appendLikedSong, appendTrack, appendLocalTracks, appendHistoryItem, addToQueue, playNext, planDownloads, resolve
- `LikedSongsManager.shared` — fetchLikedSongs, `likedSongsUpdatedNotification`
- `HistoryManager.shared` — fetchHistory, playHistoryItem, deleteHistoryItem, clearHistory, `historyUpdatedNotification`
- `LocalLibraryManager.shared` — allTracks, importFiles, deleteTrack, openMusicFolderInFinder, toggleLike
- `DownloadManager.shared` — downloadTrack, queueTrack, queueTracks
- `NowPlayingManager.shared` — currentState, playOfflineTrack, switchToOnlineMode, engineMode
- `NativeAudioPlayer.shared` — currentTrack, isPlaying, playNext
- `LocalDatabaseManager.shared` — removeLikedSong
- `CenteredMenuBarLyricsWindowController.shared` — showCustomTextOverlay
- `DynamicIslandPlayerView.sharedAmbientBgColor` / `sharedAmbientAccentColor`
- `PlayerDesign` enum (current), `GlassSearchField`, `ReactiveIconButton`, `SwipeToDeleteContainerView`, `AppArtworkHelper`
- `UserDefaults` keys `YTM_lastVideoId`, `YTM_lastTitle`

**Classes defined:**
- `protocol PlaylistLibraryViewDelegate`
- `class PlaylistLibraryView` (public)
- `enum PlaylistLibraryView.Tab` (nested, Int)
- `enum PlaylistLibraryView.Mode` (nested, private)
- `class PlaylistTableView` (public, at line 2285)
- `class PlaylistRowCellView` (private, line 2303)
- `class PlaylistItemRowCellView` (private, line 2463)
- `class DownloadRowCellView` (private, line 2738)
- `class HistoryRowCellView` (private, line 2938)
- `class LikedSongRowCellView` (private, line 3180)

**Constants:**
- `dragType = NSPasteboard.PasteboardType("com.mooziac.playlist.reorder")` (line 14)
- Accent cyan used repeatedly: `NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)` (dark themes) vs `(0.0, 0.50, 0.90)` (glass).
- Row height 44 (table), row height 40 via `heightOfRow`.
- Corner radii: root 16, tableContainer 10, bottomBar 8, header buttons 5, cells 8/6.
- Theme animation duration 0.35s (`applyTheme`).

**Properties/state (PlaylistLibraryView):**
- `weak var delegate: PlaylistLibraryViewDelegate?`
- `mode: Mode` (didSet → clears search, `reload()`)
- `allPlaylists/filteredPlaylists: [PlaylistRecord]`, `allLikedSongs/filteredLikedSongs: [LikedSongRecord]`, `allPlaylistItems/filteredPlaylistItems: [PlaylistItemRecord]`, `allDownloads/filteredDownloads: [LocalTrack]`, `allHistoryItems/filteredHistoryItems: [HistoryRecord]`
- `currentSearchQuery: String`
- `isFlipped = true` (top-left origin)
- Views: `topBar`, `backButton`, `librarySegmentedControl`, `headerTitleLabel`, `headerSubtitleLabel`, `titleStack`, 7 header `ReactiveIconButton`s (`saveQueueButton`, `importHeaderButton`, `openFolderHeaderButton`, `downloadCurrentHeaderButton`, `addCurrentTrackButton`, `downloadButton`, `moreMenuButton`), `actionStack`, `searchField`, `scrollView`, `tableView`, `tableContainer`, `bottomBar` + 3 bottom `NSButton`s, `emptyStateView`/`Icon`/`Label`/`SubLabel`.

**Events observed (NotificationCenter):**
- `"YTM_playerDesignChanged"` → `applyTheme`
- `"YTM_ambientThemeChanged"` → `applyTheme`
- `HistoryManager.historyUpdatedNotification` → `handleHistoryUpdated`
- `"Mooziac_LibraryUpdated"` → `handleDownloadsUpdated`
- `LikedSongsManager.likedSongsUpdatedNotification` → `handleLikedSongsUpdated`

**Side effects:** Reads/writes local SQLite via managers; posts `LikedSongsManager.likedSongsUpdatedNotification` after removing liked songs (lines 987, 1728, 1868, 1954); shows toast overlays; imports files into `~/Music/Mooziac`.

**Files it communicates with:** `OfflineLibraryView.swift` (parallel design), managers under `Managers/`, `DynamicIslandPlayerView` (ambient colors), `CenteredMenuBarLyricsWindowController`.

---

### CLASS — PlaylistLibraryView

- **Purpose/responsibilities:** Multi-mode library browser; single owner of a searchable, swipeable, context-menu-enabled table.
- **init(frame:)** and **init?(coder:)** → `setupUI()` → `setupObservers()` → `applyTheme()` → `reload()`.
- **Public API:** `refresh()`, `openPlaylist(id:)`, `openPlaylists()`, `openLikedSongs()`, `openDownloads()`, `openHistory()`, `playLikedSongRecord(_:)`, `menu(for:)`, drag/drop + `NSTableView` dataSource/delegate conformance, `controlTextDidChange`.
- **Private API:** all `@objc handle*` actions, `reload`, `applyFilter`, `promptForName`, `confirmAndDeletePlaylist`, `playPlaylist`, `setupUI`, `setupBottomLiquidButton`, `setupHeaderIconButton`, `setupObservers`, `show*Menu` helpers, `handleReturnAction`, `handleDeleteKeyAction`.
- **Consumers:** host view/controller that creates the view and implements `PlaylistLibraryViewDelegate` (`playlistLibraryDidRequestClose`, `playlistLibraryDidPlayOnline(videoId:)`).
- **Lifecycle:** created when library opens; observers registered in init, never explicitly removed (`UNKNOWN` — potential leak; see Risks).
- **State:** `mode` is the single source of truth for UI.
- **Events:** emits delegate close/play; posts liked-songs notification; broadcasts nothing else.
- **Relationships:** owns all cell classes + `PlaylistTableView`; consumed by `PlaylistLibraryViewDelegate`.
- **What would break if removed:** All library browsing, playlist CRUD, liked songs, downloads, history UI.

---

### CLASS — PlaylistTableView (public, ~2285)

- `NSTableView` subclass adding `onReturnKey`/`onDeleteKey` closures.
- `keyDown(with:)` (2289): keyCode 36 (Return/Enter) → `onReturnKey?()`; keyCode 51 or 117 (Delete/Forward Delete) → `onDeleteKey?()`; else `super`.

---

### CLASS — PlaylistRowCellView (private, 2303)

- Layout: `SwipeToDeleteContainerView` filling cell; inside content card: `iconImageView` (music.note.list), `titleLabel`, `countLabel`, `chevronImageView` (chevron.right).
- Callbacks: `onRowClicked`, `onDelete`/`onRightSwipePlay` forwarded to `swipeContainer`.
- `updateTrackingAreas`/`mouseEntered`/`mouseExited` (2410–2431): hover highlight — glass `white(0.0,0.05)` bg, dark `white(1.0,0.08)`; exit restores 0.02/0.04. Skipped when `swipeContainer.isSwipedOpen`.
- `configure(playlist:summary:design:)` (2433): closes swipe, sets title/count, applies theme colors (glass vs dark).

---

### CLASS — PlaylistItemRowCellView (private, 2463)

- Layout: swipe container + `containerView` (0.5pt border, radius 6) containing `artImageView` (28×28, radius 5), `nowPlayingWave` (SF `waveform`, hidden unless current), title/artist stack, `statusIcon`, `durationLabel` (monospaced 10.5, width 40), `optionsButton` (ellipsis → `handleOptions`).
- Static `webImageCache: NSCache<NSString, NSImage>` for online artwork (line 2483); `currentArtworkKey` guards stale async image swaps.
- `configure(item:resolution:design:index:)` (2623): resolves current-track state via `NowPlayingManager.engineMode`; offline → compares `NativeAudioPlayer.currentTrack?.id`; online → reads `YTM_lastVideoId`/`YTM_lastTitle` from UserDefaults. Sets `statusIcon` by resolution (local = arrow.down.circle.fill green; online = icloud gray; unavailable = exclamationmark.circle red). Loads artwork: local via `AppArtworkHelper`; online via `URLSession.dataTask` + cache.

---

### CLASS — DownloadRowCellView (private, 2738)

- Same skeleton as item cell minus statusIcon: art 28×28, wave icon, title/artist, duration (monospace, width 40), options ellipsis.
- `configure(track:design:)` (2885): current-track detection is offline-only: `engineMode == .offline && NativeAudioPlayer.currentTrack?.id == track.id`. Duration formatted `"%d:%02d"` or `"--:--"`. Artwork via `AppArtworkHelper` (cached thumbnail, targetSize 56).

---

### CLASS — HistoryRowCellView (private, 2938)

- Same skeleton but `timeLabel` (relative played time, `item.relativePlayedTimeString`) instead of status icon.
- Own static `webImageCache` + `currentArtworkKey` (duplicate of item cell).
- `configure(item:design:)` (3087): current detection — offline: compares `NativeAudioPlayer.currentTrack?.fileURL.path == item.filePath`; online: compares `item.ytVideoId == YTM_lastVideoId` or title. Local artwork: constructs a dummy `LocalTrack` from file path to query `AppArtworkHelper` (line 3143).

---

### CLASS — LikedSongRowCellView (private, 3180)

- Skeleton: art 28×28, wave, title/artist, `heartIcon` (heart.fill, pink `(1.0,0.22,0.38)`), options ellipsis. No duration.
- Own static `webImageCache` + `currentArtworkKey` (third duplicate).
- `configure(record:design:)` (3329): current detection online-only via UserDefaults. Artwork: prefers matching local track (ytVideoId or file path match) else online URL fetch.

---

### PlaylistLibraryView — Function/Method Entries

**setupUI()** (~107): builds all views, constraints, registers `.fileURL` + `dragType` drag types. Key wiring:
- `librarySegmentedControl` target/action `handleSegmentChanged(_:)` (line 134).
- `tableView` delegate/dataSource self; `doubleAction = handleDoubleAction` (203); registered drag type (204); `onReturnKey`/`onDeleteKey` closures (206–211).
- Single `NSTableColumn("PlaylistColumn")` added (213).

**setupBottomLiquidButton(_:title:action:)** (333): un-bordered button, font 11.5 semibold, radius 6.
**setupHeaderIconButton(_:systemName:toolTip:action:pointSize:)** (344): 24×24 `ReactiveIconButton`, semibold SF symbol, radius 5, target/action set.
**setupObservers()** (361): registers 5 observers (see Events).

**handleLikedSongsUpdated()** (369): if mode == .likedSongs → refetch, filter, update empty state, reload.
**handleHistoryUpdated()** (378): same pattern for history.
**handleDownloadsUpdated()** (387): same pattern for downloads (uses `LocalLibraryManager.shared.allTracks`).

**applyTheme()** (396): reads `PlayerDesign.current`; 0.35s animated background/border/text-color swap for `.adaptive/.native`, `.darkMode`, `.glassMode`; calls `searchField.applyTheme(design)`; `tableView.reloadData()`. Also called via `#selector` (registered as observer).

**refresh()** (485): `reload()`.
**openPlaylist(id:)** (489): fetches playlists, sets `.detail(pl)` or `.list`.
**openPlaylists()/openLikedSongs()/openDownloads()/openHistory()** (498–516): set `selectedSegment` + `mode`.

**handleSegmentChanged(_:)** (518): maps segment index 0–3 to mode.

**reload()** (533): per-mode data fetch + filter; toggles visibility of segmented control, back button, title stack, header buttons, bottom buttons; sets search placeholder, empty-state strings/icons; `tableView.reloadData()`; scrolls to row 0 if rows exist and `scrollView.contentView.scroll(to: .zero)`.
- Playlists empty state icon: `music.note.list`; detail: `music.note`; liked: `heart.fill`; downloads: `arrow.down.circle`; history: `clock.arrow.circlepath`.

**applyFilter()** (690): lowercased query contains-match per mode (name only for playlists; title/artist for items & history; title/artist/album for liked & downloads).

**handleBackTapped()** (736): top-level modes → `delegate.playlistLibraryDidRequestClose()`; `.detail` → `openPlaylists()`.

**handleImportTapped()** (745): `NSOpenPanel` (files+dirs, multi-select, `.audio` + `.mp3`, prompt "Import Music"); on OK → `LocalLibraryManager.importFiles(from:) { reload() }`.

**handleOpenFolderTapped()** (762): `LocalLibraryManager.openMusicFolderInFinder()`.

**handleDownloadCurrentTapped()** (766): guard `NowPlayingManager.currentState.title` non-empty and ≠ "Not Playing" else toast "⚠️ Play a song online first to download it"; `targetUrl = pageUrl.isEmpty ? videoId : pageUrl`; toast "⬇ Queued download: …"; `DownloadManager.downloadTrack(urlOrVideoId:title:artist:artworkUrl:) { success,_ in main→reload }`.

**handleNewPlaylistTapped()** (789): `promptForName` → `PlaylistManager.createPlaylist(name:)`; on newID, fetch playlist and `mode = .detail(playlist)`; else reload.

**handleAddCurrentTrackToDetailPlaylist()** (802): guard `.detail`; `PlaylistManager.appendCurrentPlayingTrack(to:)`; toast "✓ Added to …" or error `res.message`; reload.

**handleSaveQueueTapped()** (813): default name = `"Queue Playlist"` or `"\(title) Radio"`; `promptForName` → `PlaylistManager.createPlaylistFromCurrentQueue(name:completion:)`; main-queue: mode = .list then `.detail` of new playlist.

**handleDownloadAllTapped()** (831): guard `.detail`; `PlaylistManager.planDownloads(for:)`; if nothing to download → toast (offline-blocked or "All tracks are downloaded"); else toast "⬇ Queued N tracks from …"; builds tuple array `(id, urlOrVideoId: ytVideoId ?? refID, title, artist, artworkUrl)` → `DownloadManager.queueTracks(...)`.

**handleMoreMenuTapped(_:)** (850): history mode → single "Clear Listening History…" item (`trash` icon, `handleClearHistoryPrompt`); detail mode → "Rename Playlist…" (keyEquivalent "r"), "Add Currently Playing Track" ("a"), "Download All Tracks" ("d"), separator, "Delete Playlist" (no key). Pops up at `(x:0, y: bounds.height+4)`.

**handleClearHistoryPrompt()** (887): warning `NSAlert` → `HistoryManager.clearHistory()`; toast "🗑 History Cleared".

**handleRenameCurrentPlaylist()** (902): `promptForName(default: playlist.name)` → `renamePlaylist`; re-enter `.detail` with updated record.
**handleDeleteCurrentPlaylist()** (915): `confirmAndDeletePlaylist(playlist)`.

**handleDoubleAction()** (920): row = clickedRow or selectedRow. Per mode: playlists → `.detail`; detail → `playPlaylist(startingAt: item.id)`; liked → `playLikedSongRecord`; downloads → `NowPlayingManager.playOfflineTrack(track, in: filteredDownloads)`; history → `HistoryManager.playHistoryItem`.

**handleReturnAction()** (945): same switch as double action (duplicated logic), using `selectedRow`.
**handleDeleteKeyAction()** (970): per mode deletes:
- playlists → `confirmAndDeletePlaylist`
- detail → `PlaylistManager.removeItem(itemID:from:)` + reload
- liked → `LocalDatabaseManager.removeLikedSong(videoId:)` + post `likedSongsUpdatedNotification` + reload
- downloads → `LocalLibraryManager.deleteTrack { reload }`
- history → `HistoryManager.deleteHistoryItem(id:)` + reload

**promptForName(title:defaultName:actionTitle:completion:)** (1003): modal `NSAlert` with 240×24 `NSTextField` accessory, first responder; on confirm trims whitespace, defaults to `"My Playlist"` when empty, calls completion.

**confirmAndDeletePlaylist(_:)** (1024): destructive alert; on confirm `PlaylistManager.deletePlaylist(id:)`; if deleted playlist is current detail → `openPlaylists()` else `reload()`.

**playPlaylist(playlistID:startingAt:)** (1043): `PlaylistManager.startPlaylist(playlistID:startingAt:shuffle:false)`.

**playLikedSongRecord(_:)** (1047, public): resolves record to local track (ytVideoId or fileURL path match) → `NowPlayingManager.playOfflineTrack(track, in: allTracks)` + toast; else online → `switchToOnlineMode()` + `PlaylistManager.playOnlineVideo(videoId:)` + toast.

**menu(for event:)** (1063): right-click context menu builder (see Context Menu section below). Selects row; builds per-mode items; returns nil when out of range.

**Context menu actions (all `@objc private`, target self, item in `representedObject`):**
- `handleContextOpenPlaylist(_:)` (1340): `.detail`.
- `handleContextAddCurrentFromList(_:)` (1345): `appendCurrentPlayingTrack` + toast + reload.
- `handleContextRename(_:)` (1356): `promptForName` → `renamePlaylist` + reload.
- `handleContextDeletePlaylist(_:)` (1364): `confirmAndDeletePlaylist`.
- `handleContextPlayItem(_:)` (1369): reads `["itemID","playlistID"]` dict → `playPlaylist(startingAt:)`.
- `handleContextPlayNextItem(_:)` (1376): `PlaylistManager.playNext(item:)` + toast.
- `handleContextAddToQueueItem(_:)` (1382): `addToQueue(item:)` + toast.
- `handleContextDownloadItem(_:)` (1388): `queueTrack(id:urlOrVideoId:ytVideoId??refID:title:artist:artworkUrl:)` + toast "⬇ Queued download: …" + reload on success.
- `handleContextMoveUpItem(_:)` (1407): validates `idx>0, idx<allPlaylistItems.count`; `allPlaylistItems.swapAt(idx, idx-1)`; `reorderItems` with mapped IDs; reload.
- `handleContextMoveDownItem(_:)` (1417): symmetric; note condition `idx >= 0` (vs `idx > 0` for up).
- `handleContextRemoveItem(_:)` (1427): `removeItem(itemID:from:)` + reload.
- `handleContextPlayDownloadItem(_:)` (1435): `NowPlayingManager.playOfflineTrack(track, in: filteredDownloads)`.
- `handleContextPlayNextDownloadItem(_:)` (1440): `NativeAudioPlayer.playNext(track:)` + toast.
- `handleContextAddDownloadToPlaylist(_:)` (1446): builds a `PlaylistItemRecord` (refType "local", refID = fileURL path, artworkUrl = fileURL path, duration formatted) → `appendPlaylistItem(item, to:)` + toast with playlist name.
- `handleContextShowDownloadInFinder(_:)` (1472): `NSWorkspace.activateFileViewerSelecting` or open music folder fallback.
- `handleContextDeleteDownloadItem(_:)` (1481): destructive alert → `deleteTrack { reload }`.
- `handleContextPlayHistoryItem(_:)` (1497): `HistoryManager.playHistoryItem`.
- `handleContextPlayNextHistoryItem(_:)` (1502): builds a synthetic `PlaylistItemRecord` from `HistoryRecord` (refType local/online) → `playNext(item:)` + toast.
- `handleContextAddToQueueHistoryItem(_:)` (1520): synthetic record → `addToQueue(item:)` + toast.
- `handleContextAddHistoryToPlaylist(_:)` (1538): synthetic record → `appendPlaylistItem` + toast.
- `handleContextDownloadHistoryItem(_:)` (1560): `queueTrack` (id: item.id, vid) + toast + reload on success.
- `handleContextDeleteHistoryItem(_:)` (1579): `deleteHistoryItem(id:)` + reload.
- `handleContextCopyDetailItemToPlaylist(_:)` (1585): deep-copies `PlaylistItemRecord` (new playlistID, sortOrder 0, copies refType/refID/ytVideoId/title/artist/artworkUrl/duration/isLiked) → `appendPlaylistItem` + toast.
- `handleContextPlayLikedSongItem(_:)` (1607): `playLikedSongRecord`.
- `handleContextPlayNextLikedSongItem(_:)` (1612): synthetic `PlaylistItemRecord` (refType "yt", isLiked true) → `playNext` + toast.
- `handleContextAddToQueueLikedSongItem(_:)` (1630): synthetic record → `addToQueue` + toast.
- `handleContextAddLikedSongToPlaylist(_:)` (1648): `PlaylistManager.appendLikedSong(to:record:)` + toast.
- `handleContextNewPlaylistWithLikedSong(_:)` (1662): promptForName (default "\(title) Playlist") → `createPlaylist` + `appendLikedSong` + `.detail`.
- `handleContextNewPlaylistWithDownload(_:)` (1677): promptForName → `createPlaylist` + `appendTrack` + `.detail`.
- `handleContextNewPlaylistWithHistory(_:)` (1692): promptForName → `createPlaylist` + `appendHistoryItem` + `.detail`.
- `handleContextDownloadLikedSongItem(_:)` (1707): `DownloadManager.downloadTrack(videoId,…)` + toast + reload on success.
- `handleContextDeleteLikedSongItem(_:)` (1725): `LocalDatabaseManager.removeLikedSong` + post notification + toast "♥ Removed…" + reload.
- `handleContextToggleLikeDownloadItem(_:)` (1733): `LocalLibraryManager.toggleLike(for: track.id)` + toast + reload.
- `handleContextNewPlaylistWithDetailItem(_:)` (2161): promptForName → `createPlaylist` + appended copy + `.detail`.

**showTrackMenu(for:in:from:index:)** (1986): inline ellipsis menu for detail items (Play / Play Next / Add to Queue / Download [if online] / Move Up / Move Down / Remove). Popup at `(0, bounds.height+4)`.
**showDownloadTrackMenu(for:from:)** (2037): Play / Play Next / Add to Playlist submenu (+New Playlist) / Like|Unlike / Show in Finder / Delete Download.
**showLikedSongTrackMenu(for:from:index:)** (2091): Play / Play Next / Add to Queue / Add to Playlist submenu / Download [if not downloaded] / Show in Finder [if downloaded] / Remove from Liked Songs.
**showHistoryTrackMenu(for:from:index:)** (2188): Play / Play Next / Add to Queue / Add to Playlist submenu / Download [if online] / Remove from History.

**controlTextDidChange(_:)** (1743): updates `currentSearchQuery`, `applyFilter()`, per-mode empty-state visibility, `tableView.reloadData()`.

**draggingEntered(_:)** (1763): `.copy` if pasteboard has `.fileURL`, else `[]`.
**performDragOperation(_:)** (1770): reads `NSURL` objects → `LocalLibraryManager.importFiles(from:) { reload }`.

**NSTableView dataSource/delegate:**
- `numberOfRows(in:)` (1782): count of current filtered array.
- `tableView(_:heightOfRow:)` (1792): 40.
- `tableView(_:viewFor:row:)` (1796): mode switch; reuses by identifier (`PlaylistRowCell`, `PlaylistItemRowCell`, `LikedSongRowCell`, `DownloadRowCell`, `HistoryRowCell`); wires `onRowClicked`, `onDelete`, `onRightSwipePlay` (playlists), `onOptionsTapped`.
  - Playlist row right-swipe play closure (1817): fetches items; empty → toast "⚠️ … is empty", return false; else `playPlaylist` + toast, return true.
- `tableView(_:rowActionsForRow:edge:)` (1924): trailing-edge destructive row actions (legacy NSTableViewRowAction, in addition to swipe container): Delete playlist / Remove item / Unlike liked song / Delete download / Delete history. Red bg `(0.92,0.20,0.22)`.
- `tableView(_:writeRowsWith:to:)` (2245): only `.detail`; archives row index via `NSKeyedArchiver`; declares `Self.dragType`.
- `tableView(_:validateDrop:proposedRow:proposedDropOperation:)` (2254): only `.detail`; `.move` when dropOperation == .above else `[]`.
- `tableView(_:acceptDrop:row:dropOperation:)` (2262): unarchives source row; adjusts target (if past source, `-1`); bounds-checks against `allPlaylistItems`; move in array; `PlaylistManager.reorderItems`; reload.

**Cell `@objc handleOptions()`** (PlaylistItem 2732 / Download 2932 / History 3174 / LikedSong 3405): forwards to `onOptionsTapped?(optionsButton)`.

---

### UI reverse-engineering — PlaylistLibraryView

| Component | State reflected | User actions | Handlers | Backend | State update | Visual result |
|---|---|---|---|---|---|---|
| Segmented control | Tab selection | Click | `handleSegmentChanged` | refetch per manager | `mode` set | reload + button visibility |
| Back button | Has parent mode | Click | `handleBackTapped` | — | `.list` or delegate close | view switch |
| Search field | `currentSearchQuery` | Type | `controlTextDidChange` | — | `applyFilter` | filtered rows + empty state |
| Header download-current | NowPlaying state | Click | `handleDownloadCurrentTapped` | `DownloadManager.downloadTrack` | — | toast, reload on success |
| Header save-queue | — | Click | `handleSaveQueueTapped` | `createPlaylistFromCurrentQueue` | mode → .detail | toast |
| Header import/folder | — | Click | `handleImportTapped`/`handleOpenFolderTapped` | `LocalLibraryManager` | reload | toast/finder |
| Header more | Detail/history | Click | `handleMoreMenuTapped` | — | — | NSMenu popup |
| Row click | Row selection | Single click on card | `SwipeContentCardView.mouseUp` → `onRowClicked` | per-mode play/`openDetail` | — | playback / drill-in |
| Row double-click / Return | Selection | Double-click / Return | `handleDoubleAction`/`handleReturnAction` | play managers | — | playback |
| Row swipe left | — | Drag left / 2-finger scroll | `SwipeToDeleteContainerView` | per-mode delete | reload | delete or open action |
| Row swipe right (playlists) | — | Drag right | `onRightSwipePlay` | `startPlaylist` | — | playback + toast |
| Row action (swipe) | — | Swipe beyond threshold | `rowActionsForRow` | per-mode delete | reload | delete |
| Right-click | Row | Right-click | `menu(for:)` | — | — | per-mode NSMenu |
| Options ellipsis (detail/download/liked/history) | Row | Click | `show*Menu` | — | — | per-mode NSMenu |
| Drag reorder (detail) | — | Drag row | `writeRowsWith`/`validateDrop`/`acceptDrop` | `reorderItems` | array swap | row moved |

---

## FILE 2 — OfflineLibraryView.swift

**Path:** `Sources/Mooziac/Views/Libraries/OfflineLibraryView.swift` (941 lines)

**Purpose:** A self-contained browser for locally imported/downloaded audio tracks (the "DOWNLOADS" screen). Search, sort-preserving filtering, playback, like toggle, swipe delete, row actions, drag-drop import, context menus, download-status bar, empty state.

**Subsystem:** Library browser UI (Views/Libraries).

**Imports:** `AppKit`, `Foundation`.

**Classes defined:**
- `protocol OfflineLibraryViewDelegate`
- `class OfflineLibraryView` (public)
- `class OfflineTrackCellView` (private, 569)
- `class OfflineTableView` (public, 788) with nested `enum OfflineMenuAction { play, playNext, toggleLike, showInFinder, delete }`

**Dependencies:** `LocalLibraryManager` (allTracks, importFiles, deleteTrack, toggleLike, openMusicFolderInFinder), `DownloadManager` (isDownloading, remainingQueueCount, `queueNotification`, `onDownloadStatusChanged`, downloadTrack), `NowPlayingManager` (playOfflineTrack, currentState), `NativeAudioPlayer` (currentTrack, isPlaying, playNext), `PlaylistManager` (fetchPlaylists, appendLocalTracks, createPlaylist), `AppArtworkHelper`, `SwipeToDeleteContainerView`, `ReactiveIconButton`, `GlassSearchField`, `PlayerDesign`, `CenteredMenuBarLyricsWindowController`.

**Properties/state:** `displayedTracks: [LocalTrack]`, `currentSearchQuery`, all subview refs (`topBar`, `backButton`, `headerTitleLabel`, `searchField`, `importButton`, `openFolderButton`, `scrollView`, `tableView`, `emptyState*`, `downloadStatusBar`/`downloadStatusLabel`/`downloadSpinner`).

**Constants:** row height 44, cell corner radius 8, art 32×32 (radius 6), title 12.5 semibold, artist 10.5, duration monospaced 11 width 45, like button 22×22; download status bar height 22 radius 6, blue `(0.0,0.55,0.95,0.22)`; delete action red `(0.93,0.20,0.22)`.

**Events:** `LocalLibraryManager.shared.onLibraryUpdated` closure; `DownloadManager.shared.onDownloadStatusChanged` closure; `DownloadManager.queueNotification` (userInfo `remaining`, `displayText`); `"YTM_playerDesignChanged"`/`"YTM_ambientThemeChanged"` → `applyTheme`.

---

### CLASS — OfflineLibraryView

- **Purpose:** browse, filter, play, like, delete, import, and queue local tracks.
- **init(frame:)/init?(coder:)** → `setupUI()` → `setupObservers()` → `applyTheme()` → `refreshLibrary()`.
- **Public:** `applyTheme()`, `refreshLibrary()`, `numberOfRows`, `tableView(_:viewFor:row:)`, `rowActionsForRow`, `controlTextDidChange`, `control(_:textView:doCommandBy:)`, `draggingEntered`, `performDragOperation`.
- **Delegate:** `OfflineLibraryViewDelegate` (track select, close, import).

**Method entries:**
- **setupUI()** (52): builds UI; registers `.fileURL` drag; download status bar visibility computed at build from `DownloadManager.isDownloading && remainingQueueCount > 0`.
- **setupIconButton** (232): 26×26 button.
- **setupObservers()** (247): library-updated closure; download-status closure toggles status bar/spinner; `queueNotification` observer updates status label with `displayText`.
- **applyTheme()** (287): 0.35s animated theme switch; glass-mode overrides empty-state text colors and icon tint.
- **refreshLibrary()** (336): recomputes busy state, clears status bar when idle, `applyFilter()`.
- **applyFilter()** (347): lowercased contains on title/artist/album; sets header "DOWNLOADS (N)"; empty state text; reload.
- **handleBackTapped()** (372): `delegate.offlineLibraryDidRequestClose()`.
- **handleImportTapped()** (376): `NSOpenPanel` (`[.audio, .mp3]`, multi, dirs) → `LocalLibraryManager.importFiles` → `refreshLibrary`.
- **handleOpenFolderTapped()** (393): `openMusicFolderInFinder`.
- **handleDownloadCurrentTapped()** (397): guard current song; on failure shows in-status-bar warning "⚠️ Play a song online first…" auto-hidden after 3s; success → `DownloadManager.downloadTrack(...)` → refresh.
- **setupTableViewMenu()** (421): wires `tableView.onRightClickTrack` (returns `LocalTrack` for row) and `tableView.onMenuAction` switch (play → delegate select; playNext → `NativeAudioPlayer.playNext`; toggleLike → `LocalLibraryManager.toggleLike` + refresh; showInFinder; delete → `confirmAndDeleteTrack`).
- **showInFinder(track:)** (445): `activateFileViewerSelecting` or open folder fallback.
- **confirmAndDeleteTrack(_:)** (453): destructive alert → `deleteTrack { refresh }`.
- **controlTextDidChange(_:)** (471): query update + refresh.
- **control(_:textView:doCommandBy:)** (476): intercepts Return; plays `displayedTracks.first` (regardless of search selection) + toast; returns true. `INFERRED FROM SOURCE`: plays top row only.
- **draggingEntered** (488): `.copy`.
- **performDragOperation** (492): reads NSURLs → `importFiles { refresh }`.
- **numberOfRows** (503): `displayedTracks.count`.
- **tableView(_:viewFor:row:)** (507): reuse `OfflineTrackCell`; `isCurrent` when `NativeAudioPlayer.currentTrack?.id == track.id`; wires `onRowClicked`, `onLikeTapped`, `onDelete`.
- **rowActionsForRow** (535): trailing delete action.
- **handleDoubleAction()** (546) / **handleReturnAction()** (553): delegate select. **handleDeleteKeyAction()** (560): confirm + delete.

---

### CLASS — OfflineTrackCellView (private, 569)

- Layout: `SwipeToDeleteContainerView` full-cell; card holds `artImageView` 32×32, title/artist stack, `durationLabel` (monospace 11, right, width 45), `likeButton` (heart SF 12pt, 22×22).
- `onDelete` computed property forwarding to `swipeContainer.onDelete` (582–585).
- `updateTrackingAreas`/`mouseEntered`/`mouseExited` (700–721): hover highlight, skipped when swiped open.
- `configure(track:isPlaying:design:)` (723): closes swipe; sets title/artist; async thumbnail via `AppArtworkHelper.getCachedThumbnail(targetSize: 64)` then `loadThumbnail` guarded by `currentTrackID == track.id`; duration formatting `"%d:%02d"` or `"--:--"`; playing title color = ambient accent or cyan; glass vs dark chrome; like icon `heart.fill` (pink `(0.98,0.25,0.35)`) vs `heart`.
- `@objc likeTapped()` (782): `onLikeTapped?()`.

---

### CLASS — OfflineTableView (public, 788)

- `NSTableView` subclass with `onRightClickTrack`, `onMenuAction`, `onReturnKey`, `onDeleteKey` closures and `OfflineMenuAction` enum.
- **keyDown** (794): Return (36) / Delete (51, 117).
- **menu(for:)** (814): builds Track Context Menu — Play (play.fill), Play Next (text.insert), Add to Playlist submenu (per playlist via `handleAddToPlaylistSubmenuItem`, + "+ New Playlist…" via `handleNewPlaylistWithTrackSubmenuItem`), separator, Like/Unlike (heart / heart.slash), Show in Finder (folder), separator, Delete Download… (trash). Items carry `representedObject` (track or dict `["playlistID", "track"]`).
- Handlers: `handlePlayItem`/`handlePlayNextItem`/`handleToggleLikeItem`/`handleShowInFinderItem`/`handleDeleteItem` (891–914) → `onMenuAction?(action, track)`; `handleAddToPlaylistSubmenuItem` (916) → `PlaylistManager.appendLocalTracks([track], to: playlistID)`; `handleNewPlaylistWithTrackSubmenuItem` (923) → alert → `createPlaylist` + `appendLocalTracks`.

---

### UI reverse-engineering — OfflineLibraryView

| Component | State | Actions | Handlers | Backend | State update | Visual |
|---|---|---|---|---|---|---|
| Search | query | Type | `controlTextDidChange` | — | filter | rows + header count |
| Return in search | — | Return | `control(_:doCommandBy:)` | `playOfflineTrack(top)` | — | playback + toast |
| Row click / dbl / Return | — | Click | `onRowClicked`/`handleDoubleAction`/`handleReturnAction` | delegate → `playOfflineTrack` | — | playback |
| Like | track.isLiked | Click | `likeTapped`/context | `toggleLike` | refresh | heart fill |
| Swipe left | — | Drag | `SwipeToDeleteContainerView` + rowActions | `deleteTrack` | refresh | delete |
| Right-click | — | Right-click | `OfflineTableView.menu(for:)` | per action | refresh | context menu |
| Drag-drop file | — | Drop | `performDragOperation` | `importFiles` | refresh | new rows |
| Download status bar | `isDownloading`/queue | — | `onDownloadStatusChanged`/queueNotification | — | — | spinner + text |

---

## FILE 3 — OfflineOverlayView.swift

**Path:** `Sources/Mooziac/Views/Libraries/OfflineOverlayView.swift` (117 lines)

**Purpose:** Full-panel offline state shown when the network drops: warning icon, message, live status label, and a Retry button with spinner feedback.

**Subsystem:** Library/player overlay UI.

**Imports:** `AppKit`.

**Class:** `public final class OfflineOverlayView: NSView`.

**Properties:** `onRetry: (() -> Void)?`; `iconImageView` (wifi.slash 44pt, tint red `(1.0,0.35,0.40)`), `titleLabel` ("No Internet Connection", 18 bold), `subtitleLabel` (12 medium, 2 lines, max width 320), `statusLabel` (11 semibold, amber `(1.0,0.75,0.30)`), `retryButton`, `spinner` (20×20, hidden).

**Methods:**
- **init/setupUI()** (13/23): layer bg `(0.07,0.07,0.09,0.96)`; vertical stack (spacing 10, centerX); retry button 28pt height.
- **@objc retryTapped()** (83): shows spinner, disables button, sets "Checking connection…", calls `onRetry?()`; after 1.5s `DispatchQueue.main.asyncAfter`: stops spinner, re-enables; if `NetworkMonitor.shared.isReachable` → green "🟢 Reconnected!" else red "⚡ Still offline…".
- **updateNetworkState(isReachable:)** (105): main-queue update of status text/color (green restored / amber offline).

**UI flow:** Offline detected → overlay shown → user clicks Retry → `onRetry?()` → network re-check → status label reflects result.

---

## FILE 4 — SwipeToDeleteContainerView.swift

**Path:** `Sources/Mooziac/Views/Libraries/SwipeToDeleteContainerView.swift` (644 lines)

**Purpose:** Apple-style swipe actions for table rows: left swipe reveals red Delete (54pt), right swipe reveals green Play. Supports mouse click-drag panning with rubber-banding, trackpad two-finger swipe, single-open coordination across lists, full-swipe triggers, shake + haptic feedback.

**Subsystem:** Reusable gesture/action component (used by all library row cells).

**Imports:** `AppKit`, `QuartzCore`.

**Classes defined:**
- `class SwipeActionCoordinator` (public, singleton) — 7–50
- `class SwipeContentCardView` (public) — 53
- `class SwipeToDeleteContainerView` (public, `NSGestureRecognizerDelegate`) — 176

**Constants/magic numbers:** `actionWidth = 54.0`; `fullSwipeRatio = 0.50`; delete red `(0.92,0.20,0.22)` / deep red `(0.82,0.12,0.15)`; play green `(0.20,0.78,0.35)`; horizontal-drag threshold `abs(deltaX) >= 3.0 && > abs(deltaY)*0.7`; vertical-forward threshold `abs(deltaY) > 6.0`; rubber-band factor 0.18; trackpad factor 0.85 and `abs(deltaX) > 1.5`; open threshold `actionWidth*0.40`; full-swipe delete offset `-bounds.width - 24`; animations 0.22s easeOut; delete delay 0.18s; shake duration 0.38 with values `[0,-14,12,-10,8,-4,2,0]`; icons trash.fill 14.5 semibold / play.fill 15 bold; icon sizes 18×18.

---

### CLASS — SwipeActionCoordinator

- **Purpose:** single-open invariant: only one row open at a time.
- `shared` singleton; `weak var activeSwipeView`.
- init (private, 12): registers `NSScrollView.didLiveScrollNotification` and `willStartLiveScrollNotification` → `closeAll()`.
- `registerOpen(_:)` (31): closes previously active (unless same), sets active.
- `unregisterOpen(_:)` (38): clears if same.
- `closeAll(except:)` (44): closes active unless excluded; nil-active.

---

### CLASS — SwipeContentCardView (53)

- The interactive content surface. `isFlipped = true`. `weak var container`.
- **mouseDown** (75): hitTest; if `isInteractiveButton(hitView)` (button or button's parent button) → close if open, else `super.mouseDown` (let button handle). Otherwise record `initialMouseLocation`, `initialOffset = container.currentOffset`, reset drag flags; if already open, intercept click (so mouseUp snaps closed) without calling super (keeps NSTableView from swallowing drags).
- **mouseDragged** (107): deltaX/deltaY; first drag: horizontal if `abs(deltaX) >= 3 && abs(deltaX) > abs(deltaY)*0.7` → `isMouseDragging=true`, `dragThresholdPassed=true`, `SwipeActionCoordinator.closeAll(except:)`, `container.beginDragging()`; vertical if `abs(deltaY) > 6` → forward to super (table scroll). While dragging → `container.handleDragOffset(initialOffset + deltaX)`.
- **mouseUp** (138): if interactive button & not dragged & not open → `super.mouseUp`. If dragged → `container.endDragging()`. If open → `container.close(animated: true)`. Else normal click → `container.onRowClicked?()`.
- **isInteractiveButton(_:)** (63): checks NSButton / ReactiveIconButton self or parent.

---

### CLASS — SwipeToDeleteContainerView (176)

- Callbacks: `onDelete`, `onRowClicked`, `onRightSwipePlay: (() -> Bool)?` (returns success; false triggers `shakeCard()`).
- State: `currentOffset`, `isSwipedOpen` (public private(set)); `isTrackpadDragging`, `startTrackpadOffset`; `deleteButtonTitle` didSet updates tooltip.
- **setupUI** (240): trailing red action container (alpha 0 initially) + trash icon + borderless `actionButton` (target `handleDeleteButtonTapped`); leading green action container + play icon; `contentCardView`; constraint set incl. `contentLeading/Trailing`, `actionLeading`, `leadingActionTrailing`.
- **updateTrackingAreas** (351).
- **beginDragging** (363): `closeAll(except: self)`.
- **handleDragOffset(_ rawOffset:)** (367): right-side positive offsets rubber-banded ×0.18 when `onRightSwipePlay == nil`; else raw. `updateOffset(animated:false)` + `updateActionAppearanceForOffset`.
- **endDragging** (384): left (delete): full-swipe if `dragDistance >= bounds.width * fullSwipeRatio` → `performFullSwipeDelete()`; else `open()` if `>= actionWidth*0.40`; else `close()`. Right (play): trigger if `dragDistance >= min(actionWidth*0.70, bounds.width*0.35)` and handler present → run handler; `close`; on failure `shakeCard()` else haptic `.generic`. Else close.
- **scrollWheel(with:)** (418): two-finger swipe. Predominantly vertical & not dragging → super (table scroll). Phases: `.began/.mayBegin` → if `|deltaX| > |deltaY|` close others, record offset, begin trackpad drag; `.changed` → `newOffset = currentOffset - (adjustedDelta*0.85)` with direction-inversion compensation, rubber-band positive when no right handler; `.ended/.cancelled` → `endDragging()`; default/momentum → forward to super when not dragging.
- **open(animated:)** (479): `currentOffset = -actionWidth`, `isSwipedOpen = true`, register with coordinator; 0.22s easeOut fade in action + trash.
- **close(animated:)** (502): reset offset 0, unregister, fade out both action containers, reset icon transforms.
- **updateOffset(animated:)** (531): sets content leading/trailing constant to `currentOffset`; sizes action containers to `max(actionWidth, |offset|)`; animates 0.22s or immediate.
- **updateActionAppearanceForOffset(_:)** (557): alpha reveal `min(1, distance/(actionWidth*0.75))`; past full-swipe → darker red + trash scale 1.22; right → green reveal + play scale 1.22.
- **handleDeleteButtonTapped()** (603): `performDeleteAnimationAndAction()`.
- **performFullSwipeDelete()** (607) / **performDeleteAnimationAndAction()** (620): haptic; offset `-bounds.width - 24`; after 0.18s → `close(animated:false)` then `onDelete?()`.
- **shakeCard()** (634): haptic + CAKeyframeAnimation on content card translation.x.
- `deinit` (233): unregister from coordinator, remove tracking area.
- `NSGestureRecognizerDelegate` conformance declared but **no `gestureRecognizer` methods implemented** (see Risks).

---

### UI reverse-engineering — Swipe

| Component | State | Actions | Handlers | Backend | State update | Visual |
|---|---|---|---|---|---|---|
| Row content | offset/isSwipedOpen | Mouse drag | mouseDown/Dragged/Up | `onDelete`/`onRightSwipePlay` | close/delete | card slides, red/green reveal |
| Row content | — | Trackpad 2-finger | `scrollWheel` | same | same | same |
| Delete button | — | Click | `handleDeleteButtonTapped` | `onDelete` | close | slide-away + delete |
| Card (open) | isSwipedOpen | Click | `mouseUp` | — | close | fade out |

---

## FILE 5 — CircularProgressDownloadButton.swift

**Path:** `Sources/Mooziac/Views/Components/CircularProgressDownloadButton.swift` (198 lines)

**Purpose:** Download-state button rendering idle/queued/downloading(progress+ETA)/completed/unavailable states with a CAShapeLayer progress ring and pulsing center square.

**Subsystem:** Reusable component (Components).

**Imports:** `AppKit`, `QuartzCore`.

**Class:** `final class CircularProgressDownloadButton: ReactiveIconButton`.

**Nested:** `enum State: Equatable { idleDownload, queued, downloading(progress: Double, eta: String), completed, unavailable }`.

**Constants:** ring line widths 1.8 (track) / 2.0 (progress); progress accent cyan `(0.0,0.85,1.0)` / glass `(0.0,0.50,0.90)`; track white 0.18/0.20 or black 0.14 (glass); center square 4×4 radius 1.2; arc start `-π/2`; min visible progress 0.04; queued pulse CAAnimation 0.8s autoreverse repeat∞.

**Methods:**
- **intrinsicContentSize** (33): image size or 15×15.
- **setupLayers()** (40): track/progress/square layers added; `updateVisuals()`.
- **layout() → updatePath()** (68/73): arc path centered, radius `min(w,h)/2 - 2`; square frame.
- **idleIconColor()** (94): glass → black `(0.082,…)`, adaptive/native → white 0.80, dark → white 0.85.
- **isDarkTheme()** (105): darkMode true; glass false; adaptive/native via `NSApp.effectiveAppearance.bestMatch`.
- **updateVisuals()** (114): per-state config. Queued → track+square visible, image nil, tooltip "Waiting in download queue... — click to cancel", start `queuedPulse` opacity 0.35↔1.0. Downloading → strokeEnd = clamped pct (CATransaction no-actions), tooltip "Downloading (N% • ETA …) — click to cancel". Completed → checkmark.circle.fill bold, green `(0.18,0.80,0.44)` or white, tooltip "Downloaded (Available Offline)". Unavailable → disabled, gray 0.4, tooltip "Song Unavailable". Idle → arrow.down.circle semibold 13.5, `idleIconColor`, tooltip "Download to Offline Library".
- **Note:** `downloadState` setter (17) → `updateVisuals()`; click-to-cancel behavior referenced only in tooltips — actual cancel wiring `UNKNOWN — requires runtime verification`.

---

## FILE 6 — GlassSearchField.swift

**Path:** `Sources/Mooziac/Views/Components/GlassSearchField.swift` (237 lines)

**Purpose:** Theme-aware search field with custom glass cell, focus animations, and custom ⌘-key handling (paste URL blocking).

**Subsystem:** Reusable component (Components).

**Imports:** `AppKit`.

**Classes:** `final class GlassSearchFieldCell: NSSearchFieldCell`; `public class GlassSearchField: NSSearchField`.

---

### CLASS — GlassSearchFieldCell (3)

- Removes search button (`searchButtonCell = nil`, 6/11); `searchButtonRect` → `.zero` (14).
- **searchTextRect(forBounds:)** (18): font height 14; x+10, width `-20` (−16 more if cancel button visible); centers vertically.
- **drawingRect/titleRect/edit/select** (30–44): all route through `searchTextRect`.
- **cancelButtonRect** (46): pinned right (`width - w - 8`), vertically centered.

---

### CLASS — GlassSearchField (54)

- Customization hooks: `onFocusChange`, `customCornerRadius`, `customIdleBorderColor`, `customIdleBgColor`, `customFocusBorderColor`, `customFocusBgColor`.
- `cellClass` → `GlassSearchFieldCell` (63).
- **setupGlassStyle()** (78): unbordered, no focus ring, font 11 medium, white text, layer bg `white 0.12 α0.35`, radius 6, border `white 0.10`; placeholder attrs (white 0.50 α0.85).
- **applyPlaylistContainerStyle(tone: SettingsTone)** (99): radius 14; light/dark custom idle/focus colors; stores in `custom*` vars; text/placeholder per tone; immediate layer paint.
- **applyTheme(_ design: PlayerDesign)** (130): early-returns if `customIdleBorderColor` set; glass → black text, bg `white 0.0 α0.06`, border `white 0.0 α0.12`, placeholder `white 0.35`; else default dark styling.
- **placeholderString didSet** (155): rebuilds attributed placeholder per design.
- **becomeFirstResponder()** (168): on first focus, 0.18s animated border/bg to focus colors (custom or default); `onFocusChange?(true)`.
- **performKeyEquivalent(with:)** (186): only for `.keyDown` + `.command` flags:
  - `"v"` paste: if `URLFilter.containsLink(pastedString)` → clears field, shows toast via delegate cast to `DynamicIslandPlayerView` ("⚠️ Links/URLs are not allowed in search", warning); else inserts via current editor.
  - `"c"`/`"x"`/`"a"` → `NSApp.sendAction` copy/cut/selectAll.
  - `"z"` → `Selector(("undo:"))`.
  - else `super`.
- **resignFirstResponder()** (220): 0.18s revert to idle colors; `onFocusChange?(false)`.
- Tracks `isFocusedState`.

---

## FILE 7 — HeaderView.swift

**Path:** `Sources/Mooziac/Views/Components/HeaderView.swift` (122 lines)

**Purpose:** Web-browser-style top bar for the YTM web view: back/forward/reload/home/account/player-only/quit buttons and a title label that reflects network state.

**Subsystem:** Reusable component (Components).

**Imports:** `AppKit`.

**Classes:** `protocol HeaderViewDelegate`; `class HeaderView: NSView`.

**Delegate methods:** `headerViewDidTapBack/Forward/Reload/Home/Account/PlayerOnly/Quit`.

**Properties:** 7 `NSButton`s, `titleLabel` ("Mooziac", 12 bold center); button tint overrides: account `systemGray`, playerOnly white, quit `systemRed` (47–49). Background `(0.11,0.11,0.13,0.98)`.

**Constants:** button 24×24, symbol 13 semibold, stacks spacing 6 (left) / 8 (right), inset 10.

**Methods:**
- **init(frame:)** (25): `setupUI()` + observer `NetworkMonitor.statusChangedNotification` → `networkStatusChanged(_:)`.
- `init?(coder:)` (31): `fatalError`.
- **setupUI()** (35): builds stacks and constraints.
- **setupIconButton(_:systemName:toolTip:action:)** (82): symbol image or falls back to title text.
- **@objc action shims** (102–108): one-line delegate forwards.
- **networkStatusChanged(_:)** (110): reads userInfo `isReachable` (default true); main-queue: online → "Mooziac" white; offline → "⚡ Mooziac (Offline)" orange `(1.0,0.60,0.30)`.

---

## FILE 8 — LiquidGlassSegmentedSlider.swift

**Path:** `Sources/Mooziac/Views/Components/LiquidGlassSegmentedSlider.swift` (310 lines)

**Purpose:** Liquid-glass segmented control (Light/System/Dark theme picker) with a sliding `NSVisualEffectView` thumb, springy 0.25s ease-in-out thumb animation, and semantic light/dark `SettingsTone` palette.

**Subsystem:** Reusable component (Components).

**Imports:** `AppKit`.

**Types:**
- `enum SettingsTone { case dark, light }` — `usesDarkThreshold`; palette: `primaryText`, `secondaryText`, `iconColor`, `dividerColor`, `sliderTrackBackground`, `sliderTrackBorder`, `systemAppearance`.
- `final class LiquidSegmentedControl: NSView` (64) — struct `Segment { icon: String?, title: String }`.
- `private final class PassThroughView: NSView` (304) — `hitTest` returns nil (labels never intercept clicks).
- `typealias LiquidGlassSegmentedSlider = LiquidSegmentedControl` (310).

**Properties:** `onSelect: ((Int) -> Void)?`; `private(set) selectedIndex`; `tone` didSet → `applyTone()`; `segments`; thumb `NSVisualEffectView` (material `.hudWindow`, `.withinWindow`, active) with shadow (black 0.35, blur 3, offset 0/1) and `thumbHighlight` CAGradientLayer (specular highlight); label containers/icons/titles arrays. Constants: `horizontalPad = 3`, `thumbInset = 3`; corner radius 8 → `bounds.height/2` on layout.

**Convenience init** (95): default segments Light (sun.max.fill) / System (circle.lefthalf.filled) / Dark (moon.fill), defaultIndex 1.

**Methods:**
- **init(segments:defaultIndex:)** (103): clamps index; `setupUI()`.
- **setupUI()** (118): thumb + highlight; per segment `PassThroughView` with icon+label stack (icon 14×14, label 10.5 semibold, spacing 4); `applyTone()`.
- **applyTone()** (192): background/border from tone; thumb appearance + border (white 0.28 / black 0.20); highlight colors (white 0.35/0.60 → 0.05); `updateLabelColors()`.
- **updateLabelColors()** (213): selected label/icon cyan `(0.0,0.85,1.0)` or glass `(0.0,0.50,0.90)`; unselected = tone.secondaryText.
- **thumbWidth()/thumbHeight()/xFor(index:)** (227–240).
- **layout()** (242): full-radius capsule, `placeThumb(animated:false)`, `placeLabels()`, `upkeepThumbVisuals()`.
- **placeThumb(animated:)** (250): target rect; 0.25s easeInEaseOut or immediate; highlight frame/corner.
- **placeLabels()** (270): equal-width segment frames.
- **setSelectedIndex(_:animated:)** (283): clamps; moves thumb + label colors.
- **mouseDown(with:)** (290): hit index by x/segWidth; if changed → set, animate thumb, colors, `onSelect?(index)`.

---

## FILE 9 — NativeCapsuleToggleView.swift

**Path:** `Sources/Mooziac/Views/Components/NativeCapsuleToggleView.swift` (69 lines)

**Purpose:** Minimal native-style capsule switch (32×18): blue track + white knob, 0.18s ease-in-out animation, `onToggle` callback.

**Subsystem:** Reusable component (Components).

**Imports:** `AppKit`, `QuartzCore`.

**Class:** `final class NativeCapsuleToggleView: NSControl`.

**Properties:** `isOn` didSet → `updateVisuals(animated: true)`; `onToggle: ((Bool) -> Void)?`; `trackLayer`, `knobLayer`.

**Constants:** size 32×18; track radius 9; knob 14×14 radius 7 inset 2; on-x 16; active blue `(0.0,0.48,1.0)` (comment: Apple #007AFF), inactive gray `white 0.28`; knob shadow (black 0.25, offset 0/1, radius 1.5); animation 0.18s easeInEaseOut.

**Methods:**
- **init(frame:)** (15): forces 32×18 frame; `setupUI()`.
- **setupUI()** (25): layers; `updateVisuals(animated:false)`.
- **updateVisuals(animated:)** (45): CATransaction animate track color + knob x.
- **mouseDown(with:)** (65): toggles `isOn`, fires `onToggle?(isOn)`.

---

## FILE 10 — ReactiveIconButton.swift

**Path:** `Sources/Mooziac/Views/Components/ReactiveIconButton.swift` (250 lines)

**Purpose:** Base button with hover/click scale animations and a suite of micro-animations (pop, bounce, heart pop, spin pop, download flow, success, error shake).

**Subsystem:** Reusable component (Components).

**Imports:** `AppKit`, `QuartzCore`.

**Class:** `class ReactiveIconButton: NSButton` (non-final; subclassed by `CircularProgressDownloadButton`).

**Properties:** `hoverScale = 1.18`; `representedObject: Any?`; `trackingArea`.

**Constants:** hover 0.15s easeOut; press 0.08s scale 0.85; release 0.12s to hoverScale; idle opacity 0.88; pop spring (from 0.70, velocity 18, mass 0.4, stiffness 320, damping 12); bounce 0.25s (x ±5, scale keyframes); heartPop 0.35s keyframes [1,1.48,0.85,1.1,1]; spinPop 0.4s full 360° + scale [1,1.30,0.85,1]; download flow 0.85s loop (translate [0,2.5,-1,0], scale [1,0.90,1.06,1], opacity [1,0.60,1]) + cyan tint `(0.0,0.75,1.0,0.95)`; success spring (0.65→1.0, velocity 14, mass 0.35, stiffness 300, damping 11) + checkmark green `(0.20,0.88,0.45)` then 1.8s revert to `arrow.down.to.line`; error shake 0.32s values [0,-3.5,3.5,-2,2,-1,1,0], red tint `(1.0,0.35,0.35,0.95)` revert 1.2s.

**Methods:**
- **commonInit()** (19): wantsLayer, `.inline` bezel, borderless.
- **viewDidMoveToWindow / setFrameSize** (25/30): `fixAnchorPoint()`.
- **fixAnchorPoint()** (35): centers layer anchor at 0.5,0.5 (preserves frame).
- **updateTrackingAreas** (44): mouse enter/exit.
- **mouseEntered/mouseExited** (59/64): `animateHover`.
- **mouseDown** (69): 0.08s press scale then `super.mouseDown`.
- **mouseUp** (77): `super` then 0.12s scale to hoverScale.
- **animateHover(isHovered:)** (85): scale hoverScale/1.0 + opacity 1.0/0.88.
- **animatePop** (95), **animateBounce(direction:)** (107), **animateHeartPop** (123), **animateSpinPop** (132): decorative layer animations (callers `UNKNOWN`).
- **startDownloadAnimation** (151) / **stopDownloadAnimation** (189) / **animateDownloadSuccess** (195) / **animateDownloadError** (236): download lifecycle (callers `UNKNOWN` — likely player download button).

---

## FILE 11 — WaveformProgressView.swift

**Path:** `Sources/Mooziac/Views/Components/WaveformProgressView.swift` (324 lines)

**Purpose:** 60+fps interactive progress bar with 4 render styles (waveform / neonGlow / cyberDots / minimalLine), hover + scrubbing tooltip thumb, animated wave phase while playing, seek callback.

**Subsystem:** Reusable component (Components).

**Imports:** `AppKit`, `QuartzCore`.

**Class:** `class InteractiveWaveformProgressView: NSView`.

**Properties:**
- `onSeek: ((Double) -> Void)?` (ratio 0…1)
- `isUserScrubbing: Bool` (public)
- `progress: Double` didSet → when not scrubbing: `needsDisplay` + `updateThumbPosition()`
- `duration: Double`
- `isPlaying` didSet → `startWaveAnimation()`/`stopWaveAnimation()`
- `accentColor` (default pink `(0.98,0.25,0.35)`) didSet → redraw
- `trackingArea`, `isHovering`, `hoverRatio`, `animationTimer`, `wavePhase`
- `baseHeights: [CGFloat]` — 32 fixed bar heights (0.35…0.95 pattern) (39–44)
- `thumbView` 9×9 white rounded (radius 4.5, shadow black blur 2 opacity 0.4), initially alpha 0.

**Constants (per style):** waveform: bar spacing 2, min bar width 2, min bar height 3, wave `sin(phase + i*0.4) * 0.20` clamped 0.20…1.0, inactive `white 0.20`; neonGlow: track height 4.5 `white 0.16`, active neon cyan `(0.0,0.85,1.0)` blur 6, white core 2.5, head dot 9 blur 8, min active width = trackH; cyberDots: 24 nodes, radius 3 (pulse 2.5…4.5 via `sin(phase + i*0.5)*0.8`), inactive `white 0.25`; minimalLine: track 2.5 `white 0.18`, radius 1.25, min active width 2.5.

**Events:** observes `"ProgressStyleDidChange"` → `progressStyleChanged()` (77): hides thumb for neonGlow/cyberDots; `ProgressStyle.current`.

**Methods:**
- **setupView()** (58): clear bg, thumb, observer, initial style sync.
- **updateTrackingAreas** (83): mouseEntered/Exited/Moved, activeInKeyWindow.
- **mouseEntered** (98): show thumb (0.15s) unless neonGlow/cyberDots.
- **mouseExited** (108): hide thumb unless scrubbing.
- **mouseMoved** (118): `hoverRatio = clamp(x/width)`; `updateThumbPosition()` (uses `progress`, not hoverRatio — see Risks).
- **mouseDownCanMoveWindow** (125): false.
- **mouseDown** (129): `isUserScrubbing = true`; show thumb; run a modal event loop (`window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp])`) updating via `updateScrubbing`; on mouseUp → `onSeek?(hoverRatio)` and hide thumb.
- **updateScrubbing(with:)** (160): sets `hoverRatio`, `progress = ratio`, redraw, move thumb.
- **updateThumbPosition()** (169): `thumbX = clamp(progress*width - 4.5, 0, width-9)`; `thumbY = (height-9)/2`.
- **startWaveAnimation()** (176): 0.12s repeating Timer, `wavePhase += 0.3`, `needsDisplay`.
- **stopWaveAnimation()** (185): invalidate, `needsDisplay`.
- **draw(_:)** (191): renders per `ProgressStyle.current`; `activeRatio = isUserScrubbing ? hoverRatio : progress`. Waveform: per-bar active when `(x+barW)/width <= activeRatio`; playing adds sinusoidal height modulation. neonGlow: bg, glowing active bar, white core, glowing head. cyberDots: 24 nodes, active pulsing radius while playing. minimalLine: thin track + accent fill.
- **formatTime(_:)** (317): `m:ss` from seconds; guards NaN/∞ → "0:00". **Note:** helper is defined but not used within this file (see Risks — caller elsewhere `UNKNOWN`).

**Seek flow:** Mouse down/drag → scrubbing ratio in `hoverRatio`/`progress` → mouse up → `onSeek?(hoverRatio)` → external player seeks → feed new `progress` back. How current time is fed in: caller sets `progress`/`duration` properties (`UNKNOWN` exact caller; likely player). Playback time display formatting lives in `formatTime` (unused here).

---

## Cross-cutting: theme system

`PlayerDesign.current` values referenced: `.adaptive`, `.native`, `.darkMode`, `.glassMode`. Ambient colors via `DynamicIslandPlayerView.sharedAmbientBgColor`/`sharedAmbientAccentColor` (static, source elsewhere). Standard theme notification names: `"YTM_playerDesignChanged"`, `"YTM_ambientThemeChanged"`. All themed views animate at 0.35s (libraries) or 0.18s (search field focus).

---

## RISKS & OBSERVATIONS

1. **Observer lifecycle leaks (probable):** `PlaylistLibraryView.setupObservers` and `OfflineLibraryView.setupObservers` (NotificationCenter blocks) and `HeaderView.init` register observers; no `deinit` removal found in `PlaylistLibraryView` (no deinit) → observers likely live until app teardown; if views are recreated per popover open, closures accumulate. `UNKNOWN — requires runtime verification`.
2. **Duplicated web-image cache:** `PlaylistItemRowCellView`, `HistoryRowCellView`, `LikedSongRowCellView` each define their own private static `webImageCache` + `currentArtworkKey` (near-identical ~60-line artwork-loading blocks). Consolidation opportunity; also each `URLSession.dataTask` lacks `resume`-failure handling.
3. **Duplicated return/delete action logic:** `handleDoubleAction` (920) and `handleReturnAction` (945) are byte-for-byte identical switch bodies.
4. **Unused/dead-ish code:**
   - `InteractiveWaveformProgressView.formatTime(_:)` (317) is never called inside the file — `UNKNOWN` external caller.
   - `InteractiveWaveformProgressView.mouseMoved` updates `hoverRatio` but thumb moves by `progress`, so hover does not visually preview position in waveform style.
   - `SwipeToDeleteContainerView` declares `NSGestureRecognizerDelegate` but implements no gesture methods.
   - `ReactiveIconButton` animation methods (`animatePop`, `animateBounce`, `animateHeartPop`, `animateSpinPop`, download lifecycle) have no call sites inside these files — `UNKNOWN` external consumers.
   - `CircularProgressDownloadButton` tooltips promise "click to cancel" but no cancel action is wired in this file.
   - `NativeCapsuleToggleView` (non-public) and `GlassSearchField.applyPlaylistContainerStyle(tone:)` have no in-file callers.
   - `PlaylistLibraryView` delegate method `playlistLibraryDidPlayOnline(videoId:)` is declared but never invoked within the file — likely external.
3. **Fragile state — drag reorder indexes:** `acceptDrop` adjusts `targetRow` by −1 when dropping below source (2269–2272) and bounds-checks against `allPlaylistItems`, but `writeRowsWith` uses the *unfiltered* index — if a search filter is active in `.detail`, source row numbers refer to `filteredPlaylistItems`, not `allPlaylistItems`, corrupting order (search field is present in detail mode). Flagged as potential bug.
4. **Inconsistent move-up/down guards:** Move Up requires `idx < allPlaylistItems.count` (1407) and Move Down `idx >= 0` (1418); Move Down lacks the `>= 0`+1 bound in the same style; minor asymmetry.
5. **Row height mismatch:** table `rowHeight = 44` but `heightOfRow` returns 40; intercell spacing 4 → effective 44; benign but confusing.
6. **Delete-key on liked songs triggers a full notification cycle** (`removeLikedSong` then post `likedSongsUpdatedNotification`, then `reload()`) — double refresh if observer is also registered on self.
7. **Swipe `performFullSwipeDelete` delay of 0.18s** then `close(animated:false)`+`onDelete` — UI feels like a dismiss animation; deletion happens after delay; rapid successive swipes could race (coordinator mitigates single-open).
8. **Trackpad scrollWheel math** uses `event.scrollingDeltaX` sign + `isDirectionInvertedFromDevice` compensation (442–443); combined with `0.85` factor and rubber-band `0.18` — tuning is heuristic; `INFERRED FROM SOURCE`, may feel different on real hardware.
9. **`mouseDown` in `SwipeContentCardView`** deliberately does NOT call `super.mouseDown` in the drag path (104) so NSTableView never sees it; means row selection is entirely manual (`selectRowIndexes` happens only in context menus) — single-click row highlight may not track selection state.
10. **OfflineLibraryView Return-in-search** plays `displayedTracks.first`, ignoring the selected row.
11. **`OfflineTableView` keyDown** intercepts Return/Delete unconditionally even when search field has focus? No — keyDown only fires on table itself; search field handles its own keys. Not an issue.
12. **`GlassSearchField` paste block** casts `self.delegate` to `DynamicIslandPlayerView` directly — if the delegate is a different object, the toast silently won't show.
13. **`HeaderView` lacks deinit** for `NetworkMonitor.statusChangedNotification` observer; `init?(coder:)` is fatal.
14. **`OfflineTrackCellView.configure`** async thumbnail guarded by `currentTrackID`, but cell reuse between different tracks of identical ID is impossible; good. However `HistoryRowCellView`/`LikedSongRowCellView`/`PlaylistItemRowCellView` online-fetch guards use `currentArtworkKey` equality — correct pattern.
15. **Potential main-thread work:** `applyFilter`/`reload` run synchronously on the main thread for potentially large libraries; `PlaylistManager.fetchPlaylists()` etc. are called on every `reload()`.
16. **Performance — `viewFor` per row** calls `PlaylistManager.summaryForPlaylist` and `resolve` (DB reads) on every scroll reuse; `LocalLibraryManager.allTracks.contains` scans in liked-song context menus (1204, 2128).
17. **`OfflineLibraryView` inherits a `handleDownloadCurrentTapped`** that shows warnings in the status bar for 3s but never resets `downloadStatusLabel` text (only hides the bar) — stale text on next show.
18. **`downloadStatusBar` frame vs `scrollView` overlap:** status bar occupies `searchField.bottom + 4` height 22; scrollView top anchored to `searchField.bottom + 6` (196–207) — when the status bar is hidden, scroll view does not extend up; cosmetic.

---

## SUMMARY

- **Files documented:** 11
- **Classes/types defined:** 27 — PlaylistLibraryView.swift: 8 (1 protocol + PlaylistLibraryView + Tab/Mode enums counted separately: protocol, class, 2 nested enums, PlaylistTableView, 5 cell classes → count as: PlaylistLibraryViewDelegate, PlaylistLibraryView, Tab, Mode, PlaylistTableView, PlaylistRowCellView, PlaylistItemRowCellView, DownloadRowCellView, HistoryRowCellView, LikedSongRowCellView = 10); OfflineLibraryView.swift: 4 (delegate protocol, OfflineLibraryView, OfflineTrackCellView, OfflineTableView + OfflineMenuAction); OfflineOverlayView: 1; SwipeToDeleteContainerView: 3; CircularProgressDownloadButton: 1 (+ State enum); GlassSearchField: 2; HeaderView: 2 (protocol + class); LiquidGlassSegmentedSlider: 4 (SettingsTone, LiquidSegmentedControl + Segment, PassThroughView, typealias); NativeCapsuleToggleView: 1; ReactiveIconButton: 1; WaveformProgressView: 1.
- **Functions/methods/selectors:** ~150 documented function/method/selector entries across all files (PlaylistLibraryView alone: ~70 including ~40 context-menu selectors + 9 table delegate/datasource methods).
- **Context menu items:** PlaylistLibraryView `menu(for:)`: 5 modes × items + 4 ellipsis menus ≈ 45 distinct menu items (Open/AddCurrent/Rename/Delete; Play/PlayNext/AddToQueue/Copy-to-Playlist+New/Download/MoveUp/MoveDown/Remove; Play/PlayNext/AddToQueue/Add-to-Playlist/Download/ShowInFinder/Unlike; Play/PlayNext/Add-to-Playlist/Like/ShowInFinder/Delete; Play/PlayNext/AddToQueue/Add-to-Playlist/Download/Delete) + more-menu (History: 1, Detail: 4) + OfflineTableView menu (7) ≈ **~55 menu items total**.
- **Risks found:** 18 observations (leaks, duplicated caches/logic, filtered-row reorder bug, unused code, stale status text, main-thread DB reads, hover thumb quirk, un-wired cancel action).

*Documentation is read-only; no source files were modified.*