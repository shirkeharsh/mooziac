# Menus

All menus and context menus in Mooziac.

## 1. App main menu (minimal)

`AppDelegate.setupMainMenu` creates a single **Edit** menu: Undo (⌘Z), Redo (⇧⌘Z), separator, Cut (⌘X), Copy (⌘C), Paste (⌘V), Select All (⌘A). This supports text editing in the search fields/web view despite the accessory app.

## 2. Status item context menu (`ContextMenu.swift`, right-click)

- **Preferences** → opens settings drawer.
- **Gesture Tutorial** (`showGestureTutorialFromMenu`).
- **Downloads Folder** → `selectDownloadLocationFromMenu` (choose) / `resetDownloadLocationFromMenu` (default `~/Music/Mooziac`).
- **Clear Listening History** (`clearListeningHistoryFromMenu`).
- **Reset Login** (`resetLoginFromMenu`) → `flushSessionState(keepCookies:false)` + reload.
- **Restart Web Engine** (`reloadFromMenu`) → posts `YTM_reloadWebView`.
- **Quit** (`quitFromMenu`).
- Gesture toggles via capsule items (master gestures, auto-pause on disconnect, right-edge volume, right-corner taps, left-corner taps) — note the matching `toggle*` selectors are **declared but not wired** (dead).

## 3. Player drawer context menus (SettingsPanel.swift)

`contextMenu(for:)` overloads per row type:

| Row type | Menu items |
| :--- | :--- |
| `LocalTrack` (playlist detail / downloads) | Play, Play Next, Add to Queue, Add to Playlist (submenu of playlists + “+ New Playlist…”), Like/Unlike, Download, Show in Finder, Remove/Delete |
| `LikedSongRecord` | Play, Play Next, Add to Playlist, Download, Show in Finder, Unlike |
| `HistoryRecord` | Play, Play Next, Add to Playlist, Like, Show in Finder, Delete |
| `PlaylistItemRecord` | Play, Play Next, Add to Queue, Add to Playlist, Download, Move Up, Move Down, Remove |

## 4. Library views context menus

### PlaylistLibraryView (≈55 items across 5 modes)
- **Playlists mode**: Open, Add Current Track, Rename, Delete (per row); more-menu on header (History/Detail actions); selection mode checkboxes + bulk delete.
- **Playlist detail mode** (per item): Play, Play Next, Add to Queue, Copy-to-Playlist (+ New), Download, Move Up, Move Down, Remove; Download-All from header; ellipsis menus.
- **Liked Songs mode**: Play, Play Next, Add to Playlist, Download, Show in Finder, Unlike, Delete.
- **Downloads mode**: Play, Play Next, Add to Playlist, Download*, Show in Finder, Delete. (*or cancel/remove)
- **History mode**: Play, Play Next, Add to Playlist, Like, Show in Finder, Delete.
- Plus swipe actions (play on right-swipe, delete on left-swipe) via `SwipeToDeleteContainerView`/`SwipeActionCoordinator`.

### OfflineLibraryView (`OfflineTableView.menu(for:)`)
Play, Play Next, Add to Queue, Add to Playlist, Like/Unlike, Download, Show in Finder, Remove — 7 items.

## 5. Header/browser toolbar

`HeaderView` buttons: Back, Forward, Reload, Home, Account (login), Player-Only (mode), Quit. (Not a menu — delegate callbacks.)

## Menu item counts (verified by analysis)

~55 items in PlaylistLibraryView menus, ~8 in status context menu, ~7 in offline table menu, ~4-6 per drawer row type.